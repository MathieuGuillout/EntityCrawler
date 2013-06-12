require "nokogiri"
require "net/http"
require "resque"

require_relative "site"
require_relative "crawler"
require_relative "helper"

class Job
  attr_reader :entities, :new_jobs, :entity_type, :export_results, :details, :style, :context
  attr_accessor :options

  @queue = :crawl_page

  def initialize entity_type, details, style, context = OpenStruct.new, options = OpenStruct.new
    @entity_type = entity_type
    @details = details
    @style = style
    @context = context
    @export_results = (@style[entity_type] and @style[entity_type].save) ? true : false   
    @entities = []
    @jobs = []
    @options = options
  end

  def new_jobs_for entities
    jobs = []
    entities.each do |entity|
      @style[@entity_type].jobs ||= []
      @style[@entity_type].jobs.each do |next_entity_type|
        jobs << Job.new(next_entity_type, entity, @style, @context, @options)
      end
    end
    jobs
  end

  def perform(crawler=Crawler)
    print "#{@details.url}\n"
    context = @details
    context.path = @context.path if @context and @context.path
    @entities = crawler.extract_entities @details.url, @style[@entity_type], context
    @new_jobs = new_jobs_for @entities

    if @options.export and @export_results
      export_method = Helper.get_export_method(@options.export) if @options.export
      export_method.call(@entities, @entity_type, @options.to)    
    end
  end


  def self.perform *args 
    args_instance = args.map do |a| (a.class == Hash) ? Helper.hostruct(a) : a end
    instance = new(*args_instance)
    instance.resque_perform()
  end

  def resque_perform(crawler=Crawler)
    perform(crawler)
    queue_new_jobs()
  end
   
  def queue_me
    Resque.enqueue(Job, 
                   @entity_type, 
                   Helper.ostructh(@details), 
                   Helper.ostructh(@style), 
                   Helper.ostructh(@context), 
                   Helper.ostructh(@options)
                   )
  end

  def queue_new_jobs
    @new_jobs.each do |job| job.queue_me() end
  end
end

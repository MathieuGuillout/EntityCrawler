require "nokogiri"
require "net/http"
require "resque"

require_relative "site"
require_relative "crawler"
require_relative "cdn"
require_relative "helper"

class Job
  attr_reader :entities, :new_jobs, :entity_type, :export_results, :details, :style, :context
  attr_accessor :options


  @queue = :crawl_page

  def initialize entity_type, details, style, context = OpenStruct.new, options = OpenStruct.new
    @entity_type = entity_type
    @details = details
    @crawl_timestamp = details.crawl_timestamp
    @style = style
    @context = context
    @export_results = (@style[entity_type] and @style[entity_type].save) ? true : false   
    @handle_diffs   = (@style[entity_type] and @style[entity_type].handle_diffs) ? @style[entity_type].handle_diffs : nil   
    @cdn_config     = @style["site"]["cdn"] || false
    @entities = []
    @jobs = []
    @options = options
  end

  def new_jobs_for entities
    jobs = []
    entities.each do |entity|
      @style[@entity_type].jobs ||= []
      @style[@entity_type].jobs.each do |next_entity_type|
        entity.crawl_timestamp = @crawl_timestamp
        jobs << Job.new(next_entity_type, entity, @style, @context, @options)
      end
    end
    jobs
  end

  def iterations 
    url = @details.url || @style[@entity_type].url

    regex_iterator = /\$\$iterator\$\$/

    first, last = @style[@entity_type].iterator.split ".."
    iterator = first..last

    jobs = []
    iterator.each do |it|
      target_url = url.gsub regex_iterator, it.to_s
      details = @details.clone
      details.url = target_url
      jobs << Job.new(@entity_type, details, @style, @context, @options)
    end

    @new_jobs = jobs
  end

  def extraction(crawler=Crawler)

    url = @details.url || @style[@entity_type].url

    context = @details

    @entities = crawler.extract_entities url, @style[@entity_type], context

    @entities = @entities.map do |entity| 
      entity.crawl_timestamp = @crawl_timestamp
      entity
    end

    @new_jobs = new_jobs_for @entities

    # If no style on the command line, but style from the stylesheet
    if not @options.export and @style["site"]["export"] 
      @options.export = @style["site"]["export"]["type"]
      @options.to = @style["site"]["export"]["connection"]
    end

    if @options.export and @export_results
      export_method = Helper.get_export_method(@options.export, "save")
      export_method.call(@entities, @entity_type, @options.to)    
    end

    if @options.export and @handle_diffs
      diff_method = Helper.get_export_method(@options.export, "diff")
      diff_method.call(url, @handle_diffs, @entities, @entity_type, @options.to)
    end

    if @cdn_config and CDN.has_a_job @style, @entity_type
      CDN.save @style, @entity_type, @entities, @cdn_config
    end

  end


  def perform(crawler=Crawler)
    url = @details.url || @style[@entity_type].url

    context = @details
    context.path = @context.path if @context and @context.path

    @entities = []
  
    regex_iterator = /\$\$iterator\$\$/
   
    if @style[@entity_type].iterator and url.match regex_iterator
      self.iterations()
    else
      self.extraction(crawler)
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

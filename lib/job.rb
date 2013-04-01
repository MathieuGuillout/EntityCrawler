require "nokogiri"
require "net/http"
require_relative "site"
require_relative "crawler"

class Job
  attr_reader :entities, :new_jobs, :entity_type, :export_results

  def initialize entity_type, details, style, context = OpenStruct.new
    @entity_type = entity_type
    @details = details
    @style = style
    @context = context
    @export_results = (@style[entity_type] and @style[entity_type].save) ? true : false   
    @entities = []
    @jobs = []
  end

  def new_jobs_for entities
    jobs = []
    entities.each do |entity|
      @style[@entity_type].jobs ||= []
      @style[@entity_type].jobs.each do |next_entity_type|
        jobs << Job.new(next_entity_type, entity, @style, @context)
      end
    end
    jobs
  end

  def run(crawler=Crawler)
    context = @details
    context.path = @context.path if @context and @context.path
    @entities = crawler.extract_entities @details.url, @style[@entity_type], context
    @new_jobs = new_jobs_for @entities
  end

end

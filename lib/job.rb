require "nokogiri"
require "net/http"
require_relative "site"
require_relative "crawler"

class Job
  attr_reader :entities, :new_jobs
  def initialize entity_type, details, style
    @entity_type = entity_type
    @details = details
    @style = style
   
    @entities = []
    @jobs = []
  end

  def new_jobs_for entities
    jobs = []
    entities.each do |entity|
      @style[@entity_type].jobs ||= []
      @style[@entity_type].jobs.each do |next_entity_type|
        jobs << Job.new(next_entity_type, entity, @style)
      end
    end
    jobs
  end

  def run(crawler=Crawler)
    @entities = crawler.extract_entities @details.url, @style[@entity_type]
    @new_jobs = new_jobs_for @entities
  end

end

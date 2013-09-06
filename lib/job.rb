require "nokogiri"
require "net/http"
require "resque"

require_relative "site"
require_relative "crawler"
require_relative "cdn"
require_relative "helper"
require_relative "job_description"

NB_MAX_ENTITIES_PER_CRAWL = 20

class Job
  attr_reader :entities, 
              :new_jobs, 
              :entity_type, 
              :export_results, 
              :details, 
              :style, 
              :context, 
              :site_name

  attr_accessor :options, 
                :failures, 
                :level


  def initialize job_description 

    @entity_type = job_description.type
    @details = OpenStruct.new(:url => job_description.url)
    @site_name = job_description.site

    @context = OpenStruct.new()
    @options = OpenStruct.new()

    @entities = []
    @new_jobs = []
    
    @job_description = job_description
  end

  def new_jobs_for_links links
    links = [] if links.nil?
   
    links.map do |link|
      details = Helper.hostruct(link)
      job = JobDescription.new(details.url, @site_name, link[:type])
      job.level = @job_description.level + 1
      job
    end
  end

  def extraction(crawler=Crawler)
    url = @details.url || @style[@entity_type].url
    print "#{@entity_type} : #{url}\n"

    ctx = @details
    ctx.cookies = @style["site"].cookies
    ctx.path = @context.path

    @entities, links = crawler.extract_entities url, @style[@entity_type], ctx 
    @new_jobs = new_jobs_for_links links

    if @style["site"]["export"] and @export_results
      @options.export = @style["site"]["export"]["type"]
      @options.to = @style["site"]["export"]["connection"]

      export_method = Helper.get_export_method(@options.export, "save")
      @entities = export_method.call(@entities, @entity_type, @options.to)    
    end


    if @cdn_config and CDN.has_a_job @style, @entity_type
      CDN.save @style, @entity_type, @entities, @cdn_config
    end
  end


  def load_style(style_factory)
    @style = style_factory.load(@site_name)
    @export_results = (@style[entity_type] and @style[entity_type].save) ? true : false
    @cdn_config     = @style["site"]["cdn"] || false
    @context.path = style_factory.path
  end

  def perform(crawler=Crawler, style_factory)
    self.load_style(style_factory)
    self.extraction(crawler)
  end

  def clean
    @entities = []
    @new_jobs = []
    @details = nil
  end
end

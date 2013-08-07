require "nokogiri"
require "net/http"
require "resque"

require_relative "site"
require_relative "crawler"
require_relative "cdn"
require_relative "helper"

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
                :level,
                :offset


  def initialize entity_type, details, site_name, context = OpenStruct.new, options = OpenStruct.new
    @entity_type = entity_type
    @details = details
    @crawl_timestamp = details.crawl_timestamp
    @site_name = site_name
    @context = context
    @level = 0
    @offset = 0
    @entities = []
    @jobs = []
    @options = options
    @failures = 0
  end

  def new_jobs_for entities
    jobs = []
    entities.each do |entity|
      @style[@entity_type].jobs ||= []
      @style[@entity_type].jobs.each do |next_entity_type|
        entity.crawl_timestamp = @crawl_timestamp
        job = Job.new(next_entity_type, entity, @site_name, @context, @options)
        job.level = @level + 1
        jobs << job
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
      jobs << Job.new(@entity_type, details, @site_name, @context, @options)
    end

    @new_jobs = jobs
  end

  def extraction(crawler=Crawler)

    url = @details.url || @style[@entity_type].url

    context = @details
    context.cookies = @style["site"].cookies

    next_url, @entities = crawler.extract_entities url, @style[@entity_type], context

    @entities = @entities.map do |entity| 
      entity.crawl_timestamp = @crawl_timestamp
      entity
    end

    @entities = @entities[@offset, NB_MAX_ENTITIES_PER_CRAWL]

    repage_job = nil
    if @entities.length == NB_MAX_ENTITIES_PER_CRAWL
      repage_job = self.clone()
      repage_job.clean()
      repage_job.offset += NB_MAX_ENTITIES_PER_CRAWL
    end

    @new_jobs = new_jobs_for @entities
    @new_jobs << repage_job if not repage_job.nil?

    if not next_url.nil?
      new_job = self.clone()
      new_job.clean()
      new_job.details.url = next_url
      @new_jobs << new_job
    end


    # If no style on the command line, but style from the stylesheet
    if not @options.export and @style["site"]["export"] 
      @options.export = @style["site"]["export"]["type"]
      @options.to = @style["site"]["export"]["connection"]
    end

    if @options.export and @export_results
      export_method = Helper.get_export_method(@options.export, "save")
      @entities = export_method.call(@entities, @entity_type, @options.to)    
    end

    if @options.export and @handle_diffs
      diff_method = Helper.get_export_method(@options.export, "diff")
      diff_method.call(url, @handle_diffs, @entities, @entity_type, @options.to)
    end

    if @cdn_config and CDN.has_a_job @style, @entity_type
      CDN.save @style, @entity_type, @entities, @cdn_config
    end
  end


  def load_style(style_factory)
    @style = style_factory.load(@site_name)
    @export_results = (@style[entity_type] and @style[entity_type].save) ? true : false
    #@handle_diffs   = @style[entity_type].handle_diffs || false
    @handle_diffs   = false
    @cdn_config     = @style["site"]["cdn"] || false
  end

  def perform(crawler=Crawler, style_factory)

    @new_jobs = []

    self.load_style(style_factory)

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

  def clean
    @entities = []
    @new_jobs = []
  end
end

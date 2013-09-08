require 'commander/import'
require 'resque'

require_relative '../lib/site'
require_relative '../lib/helper'
require_relative '../lib/crawling_queue'
require_relative '../lib/style_factory'

program :name, 'entitycrawl'
program :version, '0.0.1'
program :description, 'Crawl a web site to extract structured data'

command :'crawl' do |c|
  c.syntax = 'crawl <stylesheet_path> [options]'
  c.description = "Extract entities from a web site according to a stylesheet"
  c.option '--export TYPE', String, "Export the entities (stdout, mongo, json)"
  c.option '--to PARAMS', String, "Pass params to export (db string connection, folder, etc..)"
  c.option "--resque", "Queue jobs in resque / redis configured instance"
  c.option "--folder", "Read all stylesheets from a path"

  # Developer helpers
  c.option "--threads NB", String, "Run locally with NB threads"
  c.option "--url URL", String, "Url to crawl"
  c.option "--resume", "Resume from the DB queued tasks"
  c.option "--debug", "Debug mode, really verbose"
  c.option "--entity ENTITY", String, "Type of entity to crawl"

  c.action { |args, options| 
    if not options.url then
      crawl_website(args.first, options) 
    else
      crawl_url(args.first, options.entity, options.url) 
    end
  }
end

# Should be used only for dev purposes.
# Useful to debug or create a stylesheet
def crawl_url stylesheet_path, entity_type, url
  site = Site.new stylesheet_path
  details = site.style[entity_type].attributes
  details.url = url
  job = Job.new(entity_type, details, site.style, site.context) 
  job.perform()
end



def job_site_name job
  job.style.site.attributes.site_name.const
end


def crawl_website stylesheet_path, options
  jobs = []
 
 
  sites = []
  if Dir.exists? stylesheet_path 
    Dir.entries(stylesheet_path).each do |stylesheet|
      if stylesheet.match /yaml$/
        site = Site.new(File.join(stylesheet_path, stylesheet))
        sites << site if site.style.site.crawl 
      end
    end
  else
    sites << Site.new(stylesheet_path)
  end
 
  sites.each do |site| 
    jobs += site.crawl
  end

   
  style_factory = StyleFactory.new(stylesheet_path)

  nb_threads = if options.threads then options.threads.to_i else 1 end
  queue = CrawlingQueue.new(
    :nb_threads => nb_threads,
    :sites => sites,
    :jobs  => jobs,
    :style_factory => style_factory,
    :resume => options.resume,
    :debug => options.debug
  )

  queue.run()
end



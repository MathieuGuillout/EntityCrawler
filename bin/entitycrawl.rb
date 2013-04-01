require 'commander/import'

require_relative '../lib/site'
require_relative '../lib/helper'

program :name, 'entitycrawl'
program :version, '0.0.1'
program :description, 'Crawl a web site to extract structured data'

command :'crawl' do |c|
  c.syntax = 'crawl <stylesheet_path> [options]'
  c.description = "Extract entities from a web site according to a stylesheet"
  c.option '--export TYPE', String, "Export the entities"
  c.option '--to PARAMS', String, "Pass params to export (db string connection, folder, ...)"
  c.action { |args, options| crawl_website(args.first, options) }
end

command :'entity' do |c|
  c.syntax = 'entity <stylesheet_path> <entity_name> <url> [options]'
  c.action { |args, options| crawl_entity(args.first, args[1], args[2]) }
end


def crawl_website stylesheet_path, options
  site = Site.new stylesheet_path
  export_method = Helper.get_export_method(options.export) if options.export
  jobs = site.crawl
  while jobs.length > 0 do 
    job = jobs.pop
    job.run()
    export_method.call(job.entities, job.entity_type) if options.export and job.export_results
    jobs += job.new_jobs
  end
end

def crawl_entity stylesheet_path, entity, url
  style = (Stylesheet.new stylesheet_path).style
  job = Job.new entity, OpenStruct.new(:url => url), style
  job.run()
end





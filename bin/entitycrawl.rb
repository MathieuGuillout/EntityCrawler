require 'commander/import'
require 'awesome_print'

require_relative '../lib/site'

program :name, 'entitycrawl'
program :version, '0.0.1'
program :description, 'Crawl a web site to extract structured data'

command :'crawl' do |c|
  c.syntax = 'crawl <stylesheet_path> [options]'
  c.action { |args, options| crawl_website(args.first) }
end

command :'entity' do |c|
  c.syntax = 'entity <stylesheet_path> <entity_name> <url> [options]'
  c.action { |args, options| crawl_entity(args.first, args[1], args[2]) }
end

def crawl_website stylesheet_path
  site = Site.new stylesheet_path
  jobs = site.crawl
  while jobs.length > 0 do 
    job = jobs.pop
    job.run()
    jobs += job.new_jobs
  end
end

def crawl_entity stylesheet_path, entity, url
  style = (Stylesheet.new stylesheet_path).style
  job = Job.new entity, OpenStruct.new(:url => url), style
  job.run()
end





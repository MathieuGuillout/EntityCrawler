require 'commander/import'
require 'resque'

require_relative '../lib/site'
require_relative '../lib/helper'

program :name, 'entitycrawl'
program :version, '0.0.1'
program :description, 'Crawl a web site to extract structured data'

command :'crawl' do |c|
  c.syntax = 'crawl <stylesheet_path> [options]'
  c.description = "Extract entities from a web site according to a stylesheet"
  c.option '--export TYPE', String, "Export the entities (stdout, mongo)"
  c.option '--to PARAMS', String, "Pass params to export (db string connection)"
  c.action { |args, options| crawl_website(args.first, options) }
end

command :'entity' do |c|
  c.syntax = 'entity <stylesheet_path> <entity_name> <url> [options]'
  c.action { |args, options| crawl_entity(args.first, args[1], args[2]) }
end

command :'worker' do |c|
  c.syntax = 'worker'
  c.action { |args, options| work() }
end


def work 
  klass, args = Resque.reserve(:crawl_page)
  if klass.respond_to? :perform
    klass.perform(*args)   
  end
end



def crawl_website stylesheet_path, options
  site = Site.new stylesheet_path
  jobs = site.crawl

  jobs = jobs.map do |job|
    job.options = { :export => options.export, :to => options.to }
    job
  end

  jobs.each do |job| job.queue_me() end
end

def crawl_entity stylesheet_path, entity, url
  style = (Stylesheet.new stylesheet_path).style
  job = Job.new entity, OpenStruct.new(:url => url), style
  job.run()
end

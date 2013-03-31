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


def crawl_website stylesheet_path
  site = Site.new stylesheet_path
  jobs = site.crawl
  while jobs.length > 0 do 
    job = jobs.pop

    job.run()
    ap job.entities
    jobs += job.new_jobs
  end
end

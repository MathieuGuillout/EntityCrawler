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
  c.option "--resque", "Queue jobs in resque / redis configured instance"
  c.option "--threads NB", String, "Run locally with NB threads"
  c.action { |args, options| crawl_website(args.first, options) }
end


def crawl_website stylesheet_path, options
  site = Site.new stylesheet_path
  jobs = site.crawl

  jobs = jobs.map do |job|
    job.options = Helper.hostruct({ :export => options.export, :to => options.to })
    job
  end

  # If runned in resque mode
  # We just those jobs in resque
  if options.resque

    jobs.each do |job| 
      job.queue_me() 
    end

  # If run in local threads mode
  # We just do all those jobs now with multiple threads
  elsif options.threads

    nb_threads = options.threads.to_i
    threads = []
    queue = Queue.new

    jobs.each do |job| queue << job end
  
    1.upto(nb_threads) do
      threads << Thread.new do 
        until queue.empty?
          job = queue.pop()
          job.perform()
          job.new_jobs.each do |new_job| 
            queue << new_job 
          end
        end
      end
    end

    threads.each do |t| 
      t.join 
    end

  end
end



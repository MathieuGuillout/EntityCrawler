require 'set'
require "open-uri"
require "pqueue"
require 'ostruct'
require 'bloom-filter'
require 'mongo'
require 'base64'
include Mongo

require_relative "graceful_quit"
require_relative "disk_queue"
require_relative "job_description"
require_relative "job"

TMP_FILE = "tmp.data"

class CrawlingQueue
    
  def initialize options
    @queues = {}
    @pqueues = {}

    @visited = {}
    @threads = []

    @nb_threads = options[:nb_threads]
    @style_factory = options[:style_factory]
    @db = MongoClient.new("localhost", 27017, :pool_size => 10, :pool_timeout => 10).db("queue")


    self.add_sites(options[:sites]) if options[:sites]
    self.add_jobs(options[:jobs]) if options[:jobs]
  end

  def add_site site_name
    @queues[site_name]  = DBQueue.new(site_name, @db)
    @pqueues[site_name] = DBQueue.new("p#{site_name}", @db)
    #@visited[site_name] = Set.new() if @visited[site_name].nil?
    @visited[site_name] = BloomFilter.new(size: 100_000, error_rate: 0.01) if @visited[site_name].nil?
  end

  def add_sites sites
    sites.each do |site|
      self.add_site(site.style.site.attributes.site_name.const)
    end
  end

  def add_jobs jobs
    jobs.each do |job| self.add_job(job) end
  end

  def add_job job_description 
    if job_description.type == "site"
      @queues[job_description.site] << job_description 
    else
      @pqueues[job_description.site] << job_description 
    end
  end

  def find_job site_name
    if not @pqueues[site_name].empty?
      return @pqueues[site_name].pop()
    elsif not @queues[site_name].empty?
      return @queues[site_name].pop()
    elsif
      @queues.each do |site, queue|
        return @queues[site].pop() if not queue.empty?
      end
    end
  end


  def empty?
    @queues.each do |key, queue|
      return false if not queue.empty?
    end
    @pqueues.each do |key, queue|
      return false if not queue.empty?
    end
    return true
  end

  def length
    len = 0
    @queues.each do |key, queue| len += queue.size end
    return len
  end

  def run_job site_name
    job = nil


    begin 
      job_description = self.find_job site_name
      
      return if job_description.nil?

      style = @style_factory.load(job_description.site)
      job = Job.new job_description

      job.perform(@style_factory)

      
      job.new_jobs.each do |new_job| 
        already_visited = @visited[job.site_name].include? new_job.url
        add_to_queue = not(already_visited) and 
                       (new_job.level < 3 or new_job.type != "site") and 
                       (job_description.level <= 3)

        if add_to_queue
          self.add_job(new_job) 
          @visited[new_job.site].insert new_job.url
        end
      end

    rescue => ex
      display_exception ex
    end

    job.clean() if not job.nil?
  end

  def display_exception ex
    if ex.class != OpenURI::HTTPError and not ex.to_s.match /redirection/
      p ex.class
      print "Exception : #{ex}\n" 
      ex.backtrace.each do |row|
        print row, "\n"
      end
    end
  end

  def fill_enough_to_start
    i = 0
    while self.length < @nb_threads * 10 do 
      self.run_job @queues.keys[i % @queues.keys.length] 
      i += 1
    end
  end


  def run_with_threads
    1.upto(@nb_threads) do |i|
      @threads << Thread.new do 
        self.run_job(@queues.keys[i % @queues.keys.length]) until self.empty?
      end
    end
     
    @threads.each do |t| t.join end
  end

  def run
    self.fill_enough_to_start()
    self.run_with_threads()
  end
end

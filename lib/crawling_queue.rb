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
    @stopping = false
    @style_factory = options[:style_factory]
    @resuming = options[:resume]
    @db = MongoClient.new("localhost", 27017, :pool_size => 10, :pool_timeout => 10).db("queue")



    self.add_sites(options[:sites]) if options[:sites]

    #@visited = self.urls_visited_to_resume()
    #jobs_to_resume = self.jobs_to_resume()
    #if jobs_to_resume.length > 0
    #  self.add_jobs(jobs_to_resume)
    
    if not @resuming
      self.add_jobs(options[:jobs]) if options[:jobs]
    end
  end

  def add_site site_name
    @queues[site_name] = DBQueue.new(site_name, @db)
    @pqueues[site_name] = DBQueue.new("p#{site_name}", @db)

    if @resuming
      @queues[site_name].resume()
      @pqueues[site_name].resume()
    end
  
    if @visited[site_name].nil?
      @visited[site_name] = Set.new() #BloomFilter.new size: 100_000, error_rate: 0.01
    end
  end

  def add_sites sites
    sites.each do |site|
      self.add_site site.style.site.attributes.site_name.const
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


  def print!
    @queues.each do |k, q| 
      print "#{k} : #{q.size} | "
    end
    print "\n"
  end

  def empty?
    #self.print!() if rand() > 0.999
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
    begin 
      job_description = self.find_job site_name
    
      if not job_description.nil? and not @visited[job_description.site].include? job_description.url
        
        style = @style_factory.load(job_description.site)
        job = Job.new(job_description.type, 
                      OpenStruct.new(:url => job_description.url), 
                      job_description.site)

        @visited[job_description.site] << job_description.url
        job.perform(@style_factory)

        
        job.new_jobs.each do |new_job| 
          if not new_job.url.match /https|javascript\:/
            new_job.url.gsub! /#.*$/, ''
            already_visited = @visited[job.site_name].include? new_job.url
            new_job.level = job_description.level + 1
            add_to_queue = not(already_visited) and (new_job.level < 3 or new_job.type != "site") and (job_description.level <= 3)
            self.add_job(new_job) if add_to_queue 
          end
        end

        job.clean()
      end

    rescue => ex

      if ex.class != OpenURI::HTTPError and not ex.to_s.match /redirection/
        p ex.class
        print "Exception : #{ex}\n" 
        ex.backtrace.each do |row|
          print row, "\n"
        end
      end

      #job_description.failures += 1
      #self.add_job(job_description) if job_description.failures < 3
    end
  end

  def run
    trap('INT') { self.stop_gracefully() }

    i = 0
    while self.length < @nb_threads * 10 do 
      self.run_job @queues.keys[i % @queues.keys.length] 
      i += 1
    end

    1.upto(@nb_threads) do |i|
      @threads << Thread.new do 
        self.run_job(@queues.keys[i % @queues.keys.length]) until self.empty? or @stopping
      end
    end
     
    @threads.each do |t| t.join end

    if @stopping
      print "Saving jobs to resume ...\n"
      File.open(TMP_FILE, "w") do |file|
        jobs = []
        @queues.each do |site, queue|
          while not queue.empty? do
            job = queue.pop()
            jobs << job
          end
        end


        Marshal.dump(jobs, file)
      end

      print "Saving visited urls ...\n"
      File.open("#{TMP_FILE}.visited", "w") do |file|
        Marshal.dump(@visited, file)
      end
    end

  end

  def jobs_to_resume
    jobs = [] 
    if File.exists? TMP_FILE
      File.open(TMP_FILE, "r") do |file|
        print "Resuming jobs...\n"
        jobs = Marshal.load(file) 
        print "#{jobs.length} jobs to resume ...\n"
        File.delete(TMP_FILE)
      end
    end
    jobs
  end

  def urls_visited_to_resume
    result = {}
    if File.exists? "#{TMP_FILE}.visited"
      File.open("#{TMP_FILE}.visited", "r") do |file|
        print "Resuming visited urls...\n"
        result = Marshal.load(file)
        File.delete("#{TMP_FILE}.visited")
      end
    end
    result
  end


  def stop_gracefully
    if @stopping
      print "Force exit ...\n"
      exit
    else
      @stopping = true
      print "Stopping gracefully ...\n"
    end
  end

end

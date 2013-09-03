require 'set'
require "open-uri"
require "pqueue"
require 'ostruct'
require 'bloom-filter'
require 'bunny'

require_relative "graceful_quit"
require_relative "disk_queue"
require_relative "job_description"
require_relative "job"

TMP_FILE = "tmp.data"

class LinkConsumer < Bunny::Consumer
  def cancelled?
    @cancelled
  end

  def handle_cancellation(_)
    @cancelled = true
  end
end

class CrawlingQueue
    
  def initialize options
    @channels = {}
    @queues = {}

    @conn = Bunny.new
    @conn.start

    @bunny_channel = @conn.create_channel
    

    @visited = {}
    @threads = []
    @nb_threads = options[:nb_threads]
    @stopping = false
    @style_factory = options[:style_factory]
    
    @visited = self.urls_visited_to_resume()
    self.add_sites(options[:sites]) if options[:sites]

    
    jobs_to_resume = self.jobs_to_resume()

    if jobs_to_resume.length > 0
      self.add_jobs(jobs_to_resume)
    else
      self.add_jobs(options[:jobs]) if options[:jobs]
    end
  end

  def add_site site_name
    @channels[site_name] = @conn.create_channel

    @queues[site_name] = @channels[site_name].queue(site_name, :durable => true, 
                                                               :exclusive => false, 
                                                               :auto_delete => true)
  
    if @visited[site_name].nil?
      @visited[site_name] = BloomFilter.new size: 100_000, error_rate: 0.01
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
    msg = Marshal.dump(job_description)
    @bunny_channel.default_exchange.publish(msg, :routing_key => job_description.site, 
                                                 :priority => job_description.level)
  end

  def print!
    @queues.each do |k, q| 
      print "#{k} : #{q.size} | "
    end
    print "\n"
  end

  def empty?
    self.print!() if rand() > 0.95
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

  def run_job job_description
    begin 

      if not @visited[job_description.site].include? job_description.url

        style = @style_factory.load(job_description.site)
        job = Job.new(job_description.type, 
                      OpenStruct.new(:url => job_description.url), 
                      job_description.site)

        job.perform(@style_factory)

        @visited[job_description.site].insert(job_description.url)
        
        job.new_jobs.each do |new_job| 
          already_visited = @visited[job.site_name].include? new_job.url
          self.add_job(new_job) if not already_visited
        end
      end

    rescue => ex

      if ex.class != OpenURI::HTTPError and not ex.to_s.match /redirection/
        p ex.class
        print "Exception : #{ex}\n" 
        ex.backtrace.each do |row|
          print row, "\n"
        end
      end

      job_description.failures += 1
      self.add_job(job_description) if job_description.failures < 3
    end
  end

  def run
    trap('INT') { self.stop_gracefully() }

    1.upto(@nb_threads) do |i|
      @threads << Thread.new do 
        site_name = @queues.keys[i % @queues.keys.length]
        q = @queues[site_name]
        ch = @channels[site_name]
        link_consumer = LinkConsumer.new(ch, q)

        q.subscribe(:block => true) do |d, p, payload|
          job_description = Marshal.load(payload)
          self.run_job job_description
        end

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

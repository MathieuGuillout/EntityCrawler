require 'set'
require "open-uri"
require "pqueue"
require 'ostruct'
require_relative "graceful_quit"
require_relative "disk_queue"
require_relative "job_description"
require_relative "job"

TMP_FILE = "tmp.data"

class CrawlingQueue
    
  def initialize options
    @queues = {}
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
    @queues[site_name] = DiskQueue.new()
    @visited[site_name] = Set.new() if @visited[site_name].nil?
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
    @queues[job_description.site] << job_description 
  end

  def find_job site_name
    if not @queues[site_name].empty?
      return @queues[site_name].pop()
    else
      @queues.each do |site, queue|
        return @queues[site].pop() if not queue.empty?
      end
    end
  end


  def print!
    @queues.each do |k, q| 
      print "#{k} : #{q.length} | "
    end
    print "\n"
  end

  def empty?
    self.print!() if rand() > 0.95
    @queues.each do |key, queue|
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

      if not @visited[job_description.site].include? job_description.url

        style = @style_factory.load(job_description.site)
        job = Job.new(job_description.type, 
                      OpenStruct.new(:url => job_description.url), 
                      job_description.site)

        job.perform(@style_factory)

        @visited[job_description.site].add(job_description.url)
        
        job.new_jobs.each do |new_job| 
          already_visited = @visited[job.site_name].include? new_job.url
          @queues[job_description.site] << new_job if not already_visited
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
      @queues[job_description.site] << job_description if job.failures < 3
    end
  end

  def run
    trap('INT') { self.stop_gracefully() }

    i = 0
    while self.length < @nb_threads do 
      self.run_job @queues.keys[i % @queues.keys.length] 
      i += 1
    end

    if @nb_threads == 1
      self.run_job(@queues.keys[i % @queues.keys.length]) until self.empty? or @stopping
    else
      1.upto(@nb_threads) do |i|
        @threads << Thread.new do 
          self.run_job(@queues.keys[i % @queues.keys.length]) until self.empty? or @stopping
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

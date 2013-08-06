require 'pqueue'
require_relative "graceful_quit"

class CrawlingQueue
    
  def initialize options
    @queues = {}
    @threads = []
    @nb_threads = options[:nb_threads]
    @stopping = false
    @style_factory = options[:style_factory]

    @nb_extracted_entities = 0
    
    self.add_sites(options[:sites]) if options[:sites]
    self.add_jobs(options[:jobs]) if options[:jobs]
  end

  def add_site site_name
    @queues[site_name] = PQueue.new() { |job_1, job_2| 
      job_1.level > job_2.level  
    }
  end

  def add_sites sites
    sites.each do |site|
      self.add_site site.style.site.attributes.site_name.const
    end
  end

  def add_jobs jobs
    jobs.each do |job| self.add_job(job) end
  end

  def add_job job
    @queues[job.site_name] << job 
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
    @queues.each do |key, queue| len += queue.length end
    return len
  end

  def run_job site_name
    begin 
      job = self.find_job site_name
      job.perform(@style_factory)
      
      @nb_extracted_entities += job.entities.length

      job.new_jobs.each do |new_job| 
        @queues[job_site_name(job)] << new_job 
      end
    rescue => ex
      print "Exception : #{ex}\n" 
      ex.backtrace.each do |row|
        print row, "\n"
      end

      job.failures += 1
      @queues[job_site_name(job)] << job if job.failures < 3
    end
  end

  def run
    trap('INT') {
      self.stop_gracefully()
    }

    i = 0
    while self.length < @nb_threads do 
      self.run_job @queues.keys[i % @queues.keys.length] 
      i += 1
    end

    if @nb_threads > 1 
      1.upto(@nb_threads) do |i|
        @threads << Thread.new do 
          self.run_job(@queues.keys[i % @queues.keys.length]) until self.empty? or @stopping
        end
      end

      @threads.each do |t| t.join end
    else
      i = 0
      until self.empty? or @stopping
        self.run_job(@queues.keys[i % @queues.keys.length])
        i += 1
      end
    end
    # TODO : Save the remaining jobs (if the program has been interrupted)
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

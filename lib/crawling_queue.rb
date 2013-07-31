class CrawlingQueue
    
  def initialize options
    @queues = {}
    @threads = []
    @nb_threads = options[:nb_threads]

    @nb_extracted_entities = 0
    
    self.add_sites(options[:sites]) if options[:sites]
    self.add_jobs(options[:jobs]) if options[:jobs]
  end

  def add_site site_name
    @queues[site_name] = Queue.new
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
    site_name = job.style.site.attributes.site_name.const
    @queues[site_name] << job 
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
    print "Nb extracted: #{@nb_extracted_entities}\n"
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
      job.perform()
      
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
    i = 0
    while self.length < @nb_threads do 
      self.run_job @queues.keys[i % @queues.keys.length] 
      i += 1
    end

    1.upto(@nb_threads) do |i|
      @threads << Thread.new do 
        self.run_job(@queues.keys[i % @queues.keys.length]) until self.empty?
      end
    end

    @threads.each do |t| t.join end
  end
end

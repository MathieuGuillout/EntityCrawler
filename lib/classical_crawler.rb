class ClassicalCrawler

  attr_accessor :jobs 

  def initialize url, style
    @url = url
    @style = style
    @jobs = {}
    @regex_links = style.urls_to_follow.find_all {|u| not u.job }.map {|l| l.regex }
    @regex_jobs  = style.urls_to_follow.find_all {|u| u.job }
    @regex_jobs.each do |r| @jobs[r.job] = [] end
  end

  def extract_links

    page = open(URI::encode(@url), 'r', :read_timeout => 5)
    doc = Nokogiri::HTML(page)

    anchors = doc.css("a")
    links = anchors.map { |a| Processor.url a["href"], { :url => @url } }

    extracted_links = []
    @regex_links.each do |reg|
      extracted_links += links.find_all{ |l| not l.nil? and l.match reg }
                              .uniq
                              .map{ |l| { :url => l, :type => "site" } }
    end

    @regex_jobs.each do |reg|
      extracted_links += links.find_all{ |l| not l.nil? and l.match reg.regex }
                              .uniq
                              .map{ |l| { :url => l, :type => reg.job } }
    end
    
    extracted_links = extracted_links.find_all {|l|
      not l[:url].match /https|javascript\:|mailto/
    }.map {|l|
      l[:url].gsub! /#.*$/, ''
      l
    }
    extracted_links
  end

  def run
    extract_links()
  end

end

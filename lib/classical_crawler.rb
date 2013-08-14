class ClassicalCrawler

  attr_accessor :jobs 

  def initialize url, style
    @url = url
    @to_crawl = [ @url ]
    @style = style
    @visited = []
    @jobs = {}
    @regex_links = style.urls_to_follow.find_all {|u| not u.job }.map {|l| l.regex }
    @regex_jobs  = style.urls_to_follow.find_all {|u| u.job }
    @regex_jobs.each do |r|
      @jobs[r.job] = []
    end
  end

  def extract_links
    url = @to_crawl.pop()
    
    @visited << url

    page = open(URI::encode(url))
    doc = Nokogiri::HTML(page)

    anchors = doc.css("a")
    links = anchors.map { |a| Processor.url a["href"], { :url => @url } }

    links_page = []
    @regex_links.each do |reg|
      links_page += links.find_all{ |l| not l.nil? and l.match reg }
    end

    @regex_jobs.each do |reg|
      jobs_page = links.find_all{ |l| not l.nil? and l.match reg.regex }
      @jobs[reg.job] += jobs_page
      @jobs[reg.job].uniq!
    end
    
    links_page -= @visited
    @to_crawl += (links_page - @visited)
    @to_crawl.uniq!

    print "URL: #{url}\n"
    print "To visit: #{@to_crawl.length} / Extracted Urls: #{@jobs["product"].length}\n"
    extract_links() if not @to_crawl.empty? 
  end

  def run
    extract_links()
  end

end

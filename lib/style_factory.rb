class StyleFactory
  
  attr_accessor :path
  def initialize(stylesheet_path)
   
    @stylesheets = {}

    sites = []
    if Dir.exists? stylesheet_path 
      Dir.entries(stylesheet_path).each do |stylesheet|
        if stylesheet.match /yaml$/
          site = Site.new(File.join(stylesheet_path, stylesheet))
          sites << site if site.style.site.crawl
        end
      end
      @path = stylesheet_path + "to_replace"
    else
      @path = stylesheet_path
      sites << Site.new(stylesheet_path)
    end
          
    sites.each do |site|       
      site_name = site.style.site.attributes.site_name.const
      @stylesheets[site_name] = site.style if site.style.site.crawl 
    end
    
  end

  def load(site_name)
    @stylesheets[site_name]
  end

end

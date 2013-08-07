class Entity

  attr_reader :type, 
              :crawl_timestamp, 
              :site_name, 
              :context,
              :url,
              :style, 
              :estyle,
              :cookies

  attr_accessor :extracted_entities, :nb_pages, :doc

  def initialize(options)
    options.each {|k,v| instance_variable_set("@#{k}",v)}
    @extracted_entities = []
    @nb_pages = 0
  end
  
  def load_style(style_factory)
    @style = style_factory.load(@site_name)
    @estyle = @style[@type]
  end

  def save()
    Helper.get_export_method(@export, "save").call(entity) if @export
  end


  def crawl(crawler)
    if @estyle.iterator and @url.match /\$\$iterator\$\$/
      first, last = @estyle.iterator.split ".."
      iterator = first..last

      iterator.each do |it|
        target_url = @url.gsub /\$\$iterator\$\$/, it.to_s
        entity = self.clone
        entity.url = target_url
        @extracted_entities << entity
      end
    else
      @extracted_entities = crawler.extract_entities self
    end
  end
end

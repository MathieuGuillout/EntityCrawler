require_relative "stylesheet"
require_relative "job_description"

class Site
  attr_accessor :style, :context

  def initialize stylesheet_path
    @context = OpenStruct.new(:path => stylesheet_path)
    stylesheet = Stylesheet.new stylesheet_path
    @style = stylesheet.style
  end

  def crawl
    @style.site.attributes.crawl_timestamp = Time.now.to_i
    url = @style.site.attributes.url
    site_name = @style.site.attributes.site_name.const

    [ JobDescription.new(url, site_name, "site") ]
  end
end

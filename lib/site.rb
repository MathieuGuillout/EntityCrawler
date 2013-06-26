require_relative "stylesheet"
require_relative "job"

class Site
  attr_accessor :style, :context

  def initialize stylesheet_path
    @context = OpenStruct.new(:path => stylesheet_path)
    stylesheet = Stylesheet.new stylesheet_path
    @style = stylesheet.style
  end

  def crawl
    @style.site.attributes.crawl_timestamp = Time.now.to_i
    [ Job.new("site", @style.site.attributes, @style, @context) ]
  end
end

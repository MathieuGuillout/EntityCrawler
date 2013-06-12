require_relative "stylesheet"
require_relative "job"

class Site
  attr_accessor :style

  def initialize stylesheet_path
    @context = OpenStruct.new(:path => stylesheet_path)
    stylesheet = Stylesheet.new stylesheet_path
    @style = stylesheet.style
  end

  def crawl
    @style.site.jobs.map do |entity| 
      job = Job.new(entity, @style.site.attributes, @style, @context)
    end
  end

end

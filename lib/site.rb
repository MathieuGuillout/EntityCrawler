require_relative "stylesheet"
require_relative "job"

class Site

  def initialize stylesheet_path
    stylesheet = Stylesheet.new stylesheet_path
    @style = stylesheet.style
  end

  def crawl
    @style.site.jobs.map do |entity| 
      Job.new(entity, @style.site.attributes, @style)
    end
  end
end

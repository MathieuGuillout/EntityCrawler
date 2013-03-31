require 'yaml'
require_relative 'helper'

class Stylesheet
  attr_reader :style

  def initialize path
    @style = Helper.hashes_to_ostruct(YAML.load_file(path))
    if @style.site.inherits
      parent_path = @style.site.inherits
      parent_path += ".yaml" unless parent_path.match /\.yaml$/
      parent_path = path.gsub /[^\/]+$/, parent_path
      parent_style = Stylesheet.new parent_path 
      p parent_style
      # Take parent attributes
      # Default string => Selector for attributes
      # Merge with parent
      # Implement postprocessors
    end
  end

end

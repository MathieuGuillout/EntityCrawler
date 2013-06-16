require 'yaml'
require 'awesome_print'
require_relative 'helper'

class Stylesheet
  attr_reader :style, :style_hash

  def post_process_attributes style
    style.each do |key, val|
      if key != "site" and style[key]["attributes"]
        style[key]["attributes"].each do |k, v|
          if v.kind_of? String
            style[key]["attributes"][k] = { :selector => v }
          end
        end
      end
    end
    style
  end

  def initialize path
    style = YAML.load_file(path)
    style = self.post_process_attributes style

    if style["site"]["inherits"]
      parent_path = style["site"]["inherits"]
      parent_path += ".yaml" unless parent_path.match /\.yaml$/
      parent_path = path.gsub /[^\/]+$/, parent_path
      parent_style = Stylesheet.new parent_path 
      style = Helper.hash_recursive_merge(parent_style.style_hash, style)
    end
    @style_hash = style
    @style = Helper.hashes_to_ostruct(style)
  end

end

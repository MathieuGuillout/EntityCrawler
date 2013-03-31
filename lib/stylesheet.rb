require 'yaml'
require_relative 'helper'

class Stylesheet
  attr_reader :style

  def initialize path
    @style = Helper.hashes_to_ostruct(YAML.load_file(path))
  end
end

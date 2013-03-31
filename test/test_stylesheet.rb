require './test/helper'
require './lib/stylesheet'

class StylesheetTest < Test::Unit::TestCase


  should "read a crawling stylesheet" do
    path = test_path "stylesheet_1.yaml"

    ss = Stylesheet.new(path)
    assert_equal ss.style.site.url, "http://www.ruby-lang.org/"
  end

end

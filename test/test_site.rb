require './test/helper'
require './lib/site'

class SiteTest < Test::Unit::TestCase


  should "give a list of jobs" do
    path = test_path "stylesheet_1.yaml"

    ss = Site.new(path)
    jobs = ss.crawl()

    assert_equal jobs.length, 1 
  end

end

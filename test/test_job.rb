require './test/helper'
require './lib/job'
require './lib/helper'

class JobTest < Test::Unit::TestCase


  should "give a list of jobs" do
    path = test_path "stylesheet1.yaml" 
 
    class CrawlerMock
      def self.extract_entities url, style, content = {}
        [ { :name => "1" }, { :name => "2" } ]
      end
    end

    job = Job.new(
      "category", 
      Helper.hostruct( :url => "data/1.html" ), 
      Helper.hostruct( :category => { :jobs => [ "sub_category" ] } )
    )

    job.perform(CrawlerMock)
    assert_equal job.new_jobs.length, 2
    assert_equal job.entities.length, 2
  end

end

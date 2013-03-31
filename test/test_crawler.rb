require './test/helper'
require './lib/job'
require './lib/helper'

class CrawlerTest < Test::Unit::TestCase


  should "should be able to extract a attribute" do
    path = test_path "1.html"
  
    style = Helper.hostruct(
      :selector => "a",
      :attributes => {
        :link => "@href"
      }
    )
    entities = Crawler.extract_entities path, style
    assert_equal entities.length, 1
    assert_equal entities.first.link , "toto"

  end

  should "should be able to extract the text content of a node if no attribute" do
    path = test_path "1.html" 
  
    style = Helper.hostruct(
      :selector => "body",
      :attributes => {
        :title => "#title"
      }
    )
    entities = Crawler.extract_entities path, style
    assert_equal entities.length, 1
    assert_equal entities.first.title , "Test Title"
  end
  
  should "should be able to extract the attribute content with a selector" do
    path = test_path "1.html" 
  
    style = Helper.hostruct(
      :selector => "body",
      :attributes => {
        :title => "a@href"
      }
    )
    entities = Crawler.extract_entities path, style
    assert_equal entities.length, 1
    assert_equal entities.first.title , "toto" 
  end
  
  should "should be able to extract the attribute content with a selector in an array" do
    path = test_path "1.html" 
  
    style = Helper.hostruct(
      :selector => "body",
      :attributes => {
        :titles => "h1@alt"
      }
    )
    entities = Crawler.extract_entities path, style
    assert_equal entities.length, 1
    assert_equal entities.first.titles.length , 2
    assert_equal entities.first.titles.first , "first_h1"
    assert_equal entities.first.titles[1] , "second_h1"

  end
  
  should "should understand a constant value" do
    path = test_path "1.html" 
  
    style = Helper.hostruct(
      :selector => "body",
      :attributes => {
        :title => "=>constant title"
      }
    )
    entities = Crawler.extract_entities path, style
    assert_equal entities.length, 1
    assert_equal entities.first.title , "constant title"

  end
end

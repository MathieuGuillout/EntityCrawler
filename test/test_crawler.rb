require './test/helper'
require './lib/job'
require './lib/helper'

class CrawlerTest < Test::Unit::TestCase


  should "should be able to extract a attribute" do
    path = test_path "1.html"
  
    style = Helper.hostruct(
      :selector => "a",
      :attributes => {
        :link => { :selector => "@href" }
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
        :title => { :selector => "#title" }
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
        :title => { :selector => "a@href" }
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
        :titles => { :selector => "h1@alt" }
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
        :title => { :const => "constant title" }
      }
    )
    entities = Crawler.extract_entities path, style
    assert_equal entities.length, 1
    assert_equal entities.first.title , "constant title"

  end
  
  should "should understand a parent value" do
    path = test_path "1.html" 
  
    style = Helper.hostruct(
      :selector => "body",
      :attributes => {
        :title => { :parent => "title" }
      }
    )
    entities = Crawler.extract_entities path, style, Helper.hostruct({:title => "ParentTitle"})
    assert_equal entities.length, 1
    assert_equal entities.first.title , "ParentTitle"

  end
  
  should "should call a handler method" do
    path = test_path "1.html" 
  
    style = Helper.hostruct(
      :selector => "body",
      :attributes => {
        :title => { :const => "title" }
      },
      :post_handlers => [ "TestHandler_1.process_test" ]
    )
    context = { :path => path }
    entities = Crawler.extract_entities path, style, Helper.hostruct(context)
    assert_equal 1, entities.length
    assert_equal true, entities.first.processed 

  end
end

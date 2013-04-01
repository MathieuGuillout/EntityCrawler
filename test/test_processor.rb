require './test/helper'
require './lib/processor'

class ProcessorTest < Test::Unit::TestCase


  should "process a decimal price" do
    path = test_path "stylesheet1.yaml" 
 
    assert_equal Processor.price("24.4"), 24.4
  end

  should "process a nil price" do
    path = test_path "stylesheet1.yaml" 
 
    assert_equal Processor.price(nil), nil 
  end
  
  should "process a price with $ in it" do
    path = test_path "stylesheet1.yaml" 
 
    assert_equal Processor.price("$43.4"), 43.4 
    assert_equal Processor.price("43.4 AUD"), 43.4 
  end
end

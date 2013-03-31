require './test/helper'
require './lib/helper'

class HelperTest < Test::Unit::TestCase

  should "transform a hash into a ostruct" do
    ob = Helper::hashes_to_ostruct({:toto => { :tata => "BIN" }})
    assert_equal ob.toto.tata, "BIN"
  end


end

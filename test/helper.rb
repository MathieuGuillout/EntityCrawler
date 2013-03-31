require 'test/unit'
require 'shoulda'


def test_path file
  File.join(File.dirname(__FILE__) , "/data/", file)
end

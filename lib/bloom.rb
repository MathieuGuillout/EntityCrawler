require 'bloom-filter'

class Bloom

  attr_reader :length

  def initialize
    @bloom = BloomFilter.new size: 100_000, error_rate: 0.01
    @length = 0
  end

  def insert what
    @bloom.insert what
    @length += 1
  end

  def include? what
    @bloom.include? what
  end

end

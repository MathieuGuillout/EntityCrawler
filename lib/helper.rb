require 'ostruct'
module Helper

  # CF http://www.dribin.org/dave/blog/archives/2006/11/17/hashes_to_ostruct/
  def Helper.hashes_to_ostruct(object)
    return case object
    when Hash
      object = object.clone
      object.each do |key, value|
        object[key] = hashes_to_ostruct(value)
      end
      OpenStruct.new(object)
    when Array
      object = object.clone
      object.map! { |i| hashes_to_ostruct(i) }
    else
      object
    end
  end

  def Helper.hostruct(object)
    Helper.hashes_to_ostruct(object)
  end

end

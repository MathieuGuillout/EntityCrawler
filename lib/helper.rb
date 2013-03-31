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

  def Helper.hash_recursive_merge(hash, other_hash)
    hash.merge(other_hash) do |key, oldval, newval|
      result = nil
      if oldval.class == hash.class 
        result = Helper.hash_recursive_merge(oldval, newval)
      else 
        result = newval  
      end
      result
    end
  end
 
end

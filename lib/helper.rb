require 'ostruct'
module Helper

  @@export_methods = {}
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

  def Helper.ostructh(struct) 
    res = {}
    struct.each_pair do |key, value|
      if value.class == OpenStruct
        res[key] = Helper.ostructh(value)
      else
        res[key] = value
      end
    end
    res
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

  def Helper.get_export_method name
    if not @@export_methods[name]
      file = "#{File.dirname(__FILE__)}/export/#{name}.rb"
      load(file)
      export_class = Kernel.const_get("EntityCrawl::#{name.capitalize}Export") 
      @@export_methods[name] = export_class.method("save")
    end
    @@export_methods[name]
  end
end
 

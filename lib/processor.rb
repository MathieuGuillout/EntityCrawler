require 'Domainatrix'

class Processor
  
  def Processor.trim value, context = {}
    (value.kind_of? Array) ? 
      value.map{|s| s.nil? ? s : s.strip} : 
      (value.nil? ? value : value.strip)
  end
  
  def Processor.price value, context = {}
    value.nil? ? value : value.gsub(/[^0-9,\.]/, '').to_f
  end

  def Processor.url value, context = {}
    val = value
    if not(value.match(/^http/)) and context[:url]
      if value.match /^\//
        link = val
        d = Domainatrix.parse context[:url]
        val = "http://#{d.subdomain}.#{d.domain}.#{d.public_suffix}#{link}"
      else
        val = context[:url].gsub(/[^\/]*$/, value)
      end
    end
    val
  end

end

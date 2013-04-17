require 'Domainatrix'

class Processor
  
  def Processor.trim value, context = {}
    (value.kind_of? Array) ? 
      value.map{|s| s.nil? ? s : s.strip} : 
      (value.nil? ? value : value.strip)
  end
  
  def Processor.price value, context = {}
    value.scan(/[1-9][0-9.\,]*/).first.to_f if value and not value.nil?
  end

  def Processor.url value, context = {}
    val = value
    if not value.nil? and not(value.match(/^http/)) and context[:url]
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

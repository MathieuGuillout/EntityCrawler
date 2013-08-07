require 'domainatrix'

class Processor

  def Processor.utrim value
    value.gsub! /\n\s*/, ' ' 
    value.strip
  end

  def Processor.trim value, context = {}
    (value.kind_of? Array) ? 
      value.map{|s| s.nil? ? s : Processor.utrim(s)} : 
      (value.nil? ? value : Processor.utrim(value))
  end
  
  def Processor.price value, context = {}
    value.scan(/[1-9][0-9.\,]*/).first.to_f if value and not value.nil?
  end

  def Processor.text value, context = {}
    if not value.nil?
      value.gsub /[\-]*\t/, '. '
    else
      nil
    end
  end

  def Processor.url value, context = {}
    val = value.strip() if not value.nil?

    if not val.nil? and not(val.match(/^http/)) and context[:url]
      if val.match /^\//
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

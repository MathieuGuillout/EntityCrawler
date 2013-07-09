require "open-uri"
require 'digest/md5'
require_relative 'helper'
require_relative 'processor'

class Crawler 
  @@handlers = {}
  def Crawler.get_attribute_value domElement, attribute, many = false, context = {}
    if attribute.kind_of? String or attribute.kind_of? Fixnum
      attribute 
    elsif attribute.const
      attribute.const
    elsif attribute.parent and context[attribute.parent]
      context[attribute.parent] 
    elsif attribute.selector
      Crawler.extract_attribute domElement, attribute.selector, many
    end
  end

  def Crawler.extract_attribute domElement, attribute, many = false
    value = nil
    selector = nil
    extractor = nil
    constant = nil
    if attribute.match /@/
      infos = attribute.split /@/
      selector = infos.first
      extractor = infos.last
    else 
      selector = attribute
    end

    elts = domElement
    elts = domElement.css(selector) if not selector.empty?
    elts = [elts] if not elts.kind_of? Nokogiri::XML::NodeSet

    values = elts.map do |elt|
      extractor.nil? ? elt.text : elt[extractor]
    end

    many ? values : values.first
  end

  def Crawler.extract_entities_page doc, style, context = {}
    entities = []
    root_elements = (style.selector.nil? || style.selector.empty?) ? [doc] : doc.css(style.selector) 
    root_elements.each do |domElement|
      entity = {}
      style.attributes.to_h.each do |key, val|

        many = key.match(/s$/) ? true : false
        v = Crawler.get_attribute_value domElement, val, many, context
        v = Crawler.post_process v, key, style, context

        entity[key] = v 
        entity[key.to_s + "_cdn"] = Digest::MD5.hexdigest(v) if val.kind_of? OpenStruct and val["cdn"]
      end
      entity = Helper.hashes_to_ostruct(entity)
      entity = Crawler.handlers entity, style, context
      entities << entity
    end
    entities
  end

  def Crawler.extract_entities url, style, context = {}

    #print "#{url}\n"
    doc = Nokogiri::HTML(open(URI::encode(url)))
    entities = Crawler.extract_entities_page doc, style, context
    
    context[:nb_pages] = 0 if not context[:nb_pages]
    context[:nb_pages] += 1

    if style.next_page and
       (not(style.next_page.max_number) or context[:nb_pages] < style.next_page.max_number) 
       
      next_url = Crawler.extract_attribute doc, style.next_page.selector
      next_url = Crawler.post_process next_url, "next_page", style, context
      next_url = Processor.url next_url, { :url => url }
      
      entities += Crawler.extract_entities(next_url, style, context) if next_url != url
    end

    entities = entities.slice(0, style["max_number"]) if style["max_number"]

    #entities.each do |e| ap Helper.ostructh(e) end
    entities
  end

  def Crawler.get_handler handler_class, context
    # Load the handler if not yet loaded
    if not @@handlers[handler_class]
      file = context.path.gsub(/[^\/]+$/, "#{handler_class}.rb")
      load(file)
      handlerClass = Kernel.const_get("PostHandlers::#{handler_class}") 
      @@handlers[handler_class] = handlerClass
    end
    @@handlers[handler_class]
  end

  def Crawler.handlers entity, style, context = OpenStruct.new
    (style.post_handlers || []).each do |post_handler|
      infos = post_handler.split /\./
      handler_class = infos.first
      handler_method = infos.last
  
      entity = Crawler.get_handler(handler_class, context).method(handler_method).call(entity)
    end

    entity
  end


  def Crawler.post_process value, attribute, style, context

    processors = []
    processors += style.attributes_post_processors || []
  
   
    if not(style.attributes[attribute].nil?) and
       not ( style.attributes[attribute].kind_of? String or style.attributes[attribute].kind_of? Fixnum )
      processors += style.attributes[attribute].post_processors || []
    end

    if (style[attribute] and style[attribute].post_processors)
      processors += style[attribute].post_processors
    end

    processors.each do |processor|
      if not processor.match /\./
        value = Processor.method(processor).call(value, context)
      else
        infos = processor.split /\./
        handler_class = infos.first
        handler_method = infos.last
        value = Crawler.get_handler(handler_class, context).method(handler_method).call(value, context) 
      end
    end
    value
  end

end

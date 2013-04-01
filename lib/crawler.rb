require "open-uri"
require_relative 'helper'
require_relative 'processor'

class Crawler 
  @@post_handlers = {}
  def Crawler.get_attribute_value domElement, attribute, many = false, context = {}

    if attribute.const
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

  def Crawler.extract_entities url, style, context = {}
    doc = Nokogiri::HTML(open(URI::encode(url)))
    entities = []
    root_elements = (style.selector.nil? || style.selector.empty?) ? [doc] : doc.css(style.selector) 
    root_elements.each do |domElement|
      entity = {}
      style.attributes.to_h.each do |key, val|
        many = key.match(/s$/) ? true : false
        v = Crawler.get_attribute_value domElement, val, many, context
        v = Crawler.post_process v, key, style, { :url => url }
        entity[key] = v 
      end
      entity = Helper.hashes_to_ostruct(entity)
      entity = Crawler.post_handlers entity, style, context
      entities << entity
    end
    entities
  end

  def Crawler.post_handlers entity, style, context = {}
    (style.post_handlers || []).each do |post_handler|
      infos = post_handler.split /\./
      handler_class = infos.first
      handler_method = infos.last

      # Load the handler if not yet loaded
      if not @@post_handlers[handler_class]
        file = context.path.gsub(/[^\/]+$/, "#{handler_class}.rb")
        load(file)
        handlerClass = Kernel.const_get("PostHandlers::#{handler_class}") 
        @@post_handlers[handler_class] = handlerClass
      end
      entity = @@post_handlers[handler_class].method(handler_method).call(entity)
    end
    entity
  end

  def Crawler.post_process value, attribute, style, context
    processors = []
    processors += style.attributes_post_processors || []
    processors += style.attributes[attribute].post_processors || []
    processors.each do |processor|
      value = Processor.method(processor).call(value, context)
    end
    value
  end

end

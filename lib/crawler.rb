require "open-uri"
require 'digest/md5'
require_relative 'helper'
require_relative 'processor'

class Crawler 
  @@handlers = {}
  def Crawler.get_attribute_value domElement, attribute, many = false, context = {}
    if attribute.kind_of? String or attribute.kind_of? Fixnum or attribute.nil?
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
        entity[key.to_s + "_cdn"] = Digest::MD5.hexdigest(v) if val.kind_of? OpenStruct and val["cdn"] and not v.nil?
      end
      entity = Helper.hashes_to_ostruct(entity)
      entity = Crawler.handlers entity, style, context
      entities << entity
    end
    entities
  end

  def Crawler.extract_entities url, style, context = {}

    entities = []

    if context.cookies
      cookie = ""
      Helper.ostructh(context.cookies).each do |key, val|
        cookie += "#{key}=#{val} ;"
      end
      context[:cookie] = cookie
    else
      context[:cookie] = ""
    end

    url = url.strip() if not url.nil?
    if url.nil? or url == ""
      return []
    end

    page = open(URI::encode(url), "Cookie" => context[:cookie])
    doc = Nokogiri::HTML(page)
    entities = Crawler.extract_entities_page doc, style, context
    
    context[:nb_pages] = 0 if not context[:nb_pages]
    context[:nb_pages] += 1

    next_url = nil

    if style.next_page
      next_url = Crawler.extract_attribute doc, style.next_page.selector

      if next_url 
        next_url = Crawler.post_process next_url, "next_page", style, context
        next_url = Processor.url next_url, { :url => url }
        next_url = nil if next_url == url
        #entities += Crawler.extract_entities(next_url, style, context) if next_url != url
      end
    end

    [ next_url, entities ]
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

    if (style[attribute] and not( style[attribute].kind_of? String or style[attribute].kind_of? String ) and
        style[attribute].post_processors)
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

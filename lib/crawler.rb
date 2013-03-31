require "open-uri"
require_relative 'helper'
require_relative 'processor'

module Crawler 
  def Crawler.extract_attribute domElement, attribute, many = false
    value = nil
    selector = nil
    extractor = nil
    constant = nil
    if attribute.match /@/
      infos = attribute.split /@/
      selector = infos.first
      extractor = infos.last
    elsif attribute.match /^=>/
      constant = attribute.gsub /^=>/, '' 
    else 
      selector = attribute
    end

    if not selector.nil? 
      elts = domElement
      elts = domElement.css(selector) if not selector.empty?
      elts = [elts] if not elts.kind_of? Nokogiri::XML::NodeSet

      values = elts.map do |elt|
        extractor.nil? ? elt.text : elt[extractor]
      end
    elsif not constant.nil?
      values = [ constant ]
    end

    many ? values : values.first
  end

  def Crawler.extract_entities url, style
    doc = Nokogiri::HTML(open(URI::encode(url)))
    entities = []
    style.selector ||= "body"
    doc.css(style.selector).each do |domElement|
      entity = {}
      style.attributes.to_h.each do |key, val|
        many = key.match(/s$/) ? true : false
        v = Crawler.extract_attribute domElement, val.selector, many
        v = Crawler.post_process v, key, style, { :url => url }
        entity[key] = v 
      end
      entities << Helper.hashes_to_ostruct(entity)
    end
    entities
  end

  def Crawler.post_process value, attribute, style, context
    processors = []
    processors += style.post_processors || []
    processors += style.attributes[attribute].post_processors || []
    processors.each do |processor|
      value = Processor.method(processor).call(value, context)
    end
    value
  end

end

require "open-uri"
require_relative 'helper'

module Crawler 
  def Crawler.extract_attribute domElement, attribute
    value = nil
    if attribute.match /@/
      infos = attribute.split /@/
      selector = infos.first
      extractor = infos.last
    else
      extractor = nil
      selector = attribute
    end

    if not extractor.nil? 
      elt = domElement
      elt = domElement.css(selector).first if not selector.empty?
      value = elt[extractor]
    else
      value = domElement.css(selector).text
    end
    value
  end

  def Crawler.extract_entities url, style
    doc = Nokogiri::HTML(open(URI::encode(url)))
    entities = []
    style.selector ||= "body"
    doc.css(style.selector).each do |domElement|
      entity = {}
      style.attributes.to_h.each do |key, val|
        entity[key] = Crawler.extract_attribute domElement, val
      end
      entities << Helper.hashes_to_ostruct(entity)
    end
    entities
  end
end

require "open-uri"
require_relative 'helper'

module Crawler 
  def Crawler.extract_entities url, style
    doc = Nokogiri::HTML(open(URI::encode(url)))
    entities = []
    style.selector ||= "body"
    doc.css(style.selector).each do |domElement|
      entity = {}
      style.attributes.to_h.each do |key, val|
        value = nil
        extractor = val
        if extractor.match /^@/
          extractor = extractor.gsub /@/, ''
          value = domElement[extractor]
        else
          value = domElement.css(extractor).text
        end
        entity[key] = value
      end
      entities << Helper.hashes_to_ostruct(entity)
    end
    entities
  end
end

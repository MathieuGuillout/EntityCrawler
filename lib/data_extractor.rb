class DataExtractor

  attr_accessor :entity, :extracted_entities

  def initialize(entity)
    @entity = entity
  end
  
  def get_attribute_value domElement, attribute, many = false
    if attribute.kind_of? String or attribute.kind_of? Fixnum or attribute.nil?
      attribute 
    elsif attribute.const
      attribute.const
    elsif attribute.parent and @entity[attribute.parent]
      @entity[attribute.parent] 
    elsif attribute.selector
      extract_attribute domElement, attribute.selector, many
    end
  end

  def extract_attribute domElement, attribute, many = false
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

  def run
    @extracted_entities = []
    
    root_elements = []

    if @entity.estyle.selector.nil? || @entity.estyle.selector.empty? 
      root_elements = [@entity.doc] 
    else
      root_elements = @entity.doc.css(@entity.estyle.selector)
    end

    root_elements.each do |domElement|
      extracted_data = {}

      p entity.estyle.attributes
      entity.estyle.attributes.to_h.each do |key, val|
        p key, val
        many = key.match(/s$/) ? true : false
        v = get_attribute_value domElement, val, many
        v = post_process v, key
        extracted_data[key] = v 
      end

      extracted_data = Helper.hashes_to_ostruct(extracted_data)
      @extracted_entities << extracted_data
    end

    @extracted_entities
  end
  
  def post_process a, b

  end
end

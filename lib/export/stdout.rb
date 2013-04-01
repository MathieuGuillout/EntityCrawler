require 'awesome_print'

module EntityCrawl

  class StdoutExport
    
    def StdoutExport.save entities, entity_type, params = {}
      ap "ENTITIES OF TYPE #{entity_type}"
      ap entities.map{|x| x.marshal_dump}
    end

  end
end

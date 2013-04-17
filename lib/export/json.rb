require 'JSON'
require 'open-uri'

module EntityCrawl

  class JsonExport
   

    def JsonExport.save entities, entity_type, params = ""
  
      path = params
      Dir.mkdir(path) if not Dir.exists? path
      
      path += "/#{entity_type}"
      Dir.mkdir(path) if not Dir.exists? path

      entities.each do |entity|
       
        key = entity.id 
        key.gsub! /(\/|\:\.)+/, "_"

        File.open("#{path}/#{key}.json", 'w') { |file| 
          file.write(JSON.generate(entity.marshal_dump)) 
        }
      end
    end

  end
end

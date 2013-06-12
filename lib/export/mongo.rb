require 'mongo'
include Mongo

module EntityCrawl
  class MongoExport 

    @@db = nil
    
    def MongoExport.connect params
      infos = params.split /\//
      server = infos.first
      db_name = infos.last
      @@db = MongoClient.new(server, 27017).db(db_name)
    end

    def MongoExport.save entities, entity_type, params = ""
      p entities
      MongoExport.connect(params) if @@db.nil?
      
      collection_name = "#{entity_type}s"
      collection = @@db.collection(collection_name)

      # Find existing entities 
      existing_entities = collection.find( "id" => { "$in" => entities.map(&:id) } ).to_a
      existing_entities_ids = existing_entities.map{|elt| elt["id"]}

      # Split into a list to update and a list to save
      to_add = entities.find_all{|entity| not(existing_entities_ids.include? entity.id) }
      to_update = entities.find_all{|entity| existing_entities_ids.include? entity.id }

      # Perform operations on db
      to_add.each do |entity| collection.insert(entity.marshal_dump) end
      to_update.each do |entity| collection.update({"id" => entity.id}, entity.marshal_dump) end
    end
  end
end


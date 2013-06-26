require 'mongo'
include Mongo

module EntityCrawl


  class MongoExport 

    @@db = nil

    def MongoExport.are_not_the_same entity_crawled, entity_db
      true
    end
    
    def MongoExport.connect params
      infos = params.split /\//
      server = infos.first
      db_name = infos.last
      @@db = MongoClient.new(server, 27017).db(db_name)
    end

    def MongoExport.save entities, entity_type, params = ""
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
      to_update.each do |entity| 
        entity_db = existing_entities.find_all{ |ed| entity.id == ed[:id] }.first
        update = MongoExport.are_not_the_same entity, entity_db
        collection.update({"id" => entity.id}, entity.marshal_dump) if update
      end
    end


    def MongoExport.diff parent_id, desc, entities, entity_type, params = ""
     
      MongoExport.connect(params) if @@db.nil?

      (target_collection_name, target_property) = desc.split /@/
      
      collection_name = "#{entity_type}s"
      collection = @@db.collection(collection_name)
      
      print "compute diffs on #{parent_id} with #{entity_type}\n"
      print "collection name : #{collection_name} #{entities.length}\n"
  

      to_compare = entities.map {|entity| entity[target_property] }

      previous = collection.find_one( "id" => parent_id )
  
      if previous.nil?
        entry = { "id" => parent_id, "entities" => to_compare }
        collection.insert(entry)         
      else 
        # We compare what we did have the last time 
        prev = previous["entities"]
        deleted = prev - to_compare
      
        # Update the other collection with all the items that have been removed
        target_collection = @@db.collection(target_collection_name)
        target_collection.update({ target_property => { "$in" => deleted }}, { "$set" => { "deleted" => true }})

        # Update for next crawl
        collection.update({ "id" => parent_id }, { "$set" => { "entities" => to_compare }})
      end
    end

  end
end


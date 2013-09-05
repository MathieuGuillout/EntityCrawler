require 'mongo'
include Mongo

module EntityCrawl


  class MongoExport 

    @@db = nil
    @@saving = false
    @@buffer = []

    def MongoExport.are_not_the_same entity_crawled, entity_db
      true
    end
    
    def MongoExport.connect params
      infos = params.split /\//
      server = infos.first
      db_name = infos.last
      @@db = MongoClient.new(server, 27017, :pool_size => 10, :pool_timeout => 10).db(db_name)
    end

    def MongoExport.save i_entities, entity_type, params = ""
      @@buffer << { :entities => i_entities, :type => entity_type, :params => params }  
      if not @@saving 
        MongoExport.internal_save_all()
      end
    end

    def MongoExport.internal_save_all 
      to_save = @@buffer.clone()
      @@buffer = []
      @@saving = true

      to_save.each do |r|
        MongoExport.internal_save(r[:entities], r[:type], r[:params])
      end
      @@saving = false
    end

    def MongoExport.internal_save i_entities, entity_type, params = ""
      MongoExport.connect(params) if @@db.nil?
      

     
      entities = i_entities.find_all { |e|
        not e.title.nil? and not e.price.nil? 
      }

      collection_name = "#{entity_type}s"
      collection = @@db.collection(collection_name)

      # Find existing entities 
      existing_entities = collection.find( "id" => { "$in" => entities.map(&:id) } ).to_a
      existing_entities_ids = existing_entities.map{|elt| elt["id"]}

      entities = entities.map {|entity|
        entity.update = existing_entities_ids.include? entity.id  
        entity
      }

      # Split into a list to update and a list to save
      to_add = entities.find_all{|entity| 
        not(existing_entities_ids.include? entity[:id]) 
      }
      to_update = entities.find_all{|entity| existing_entities_ids.include? entity.id }

      # Perform operations on db
      to_add.each do |entity| collection.insert(entity.marshal_dump) end
      to_update.each do |entity| 
        entity_db = existing_entities.find_all{ |ed| entity.id == ed[:id] }.first
        update = MongoExport.are_not_the_same entity, entity_db
        collection.update({"id" => entity.id}, entity.marshal_dump) if update
      end

      entities
    end


    def MongoExport.diff parent_id, desc, entities, entity_type, params = ""
     
      MongoExport.connect(params) if @@db.nil?

      (target_collection_name, target_property) = desc.split /@/
      
      collection_name = "#{entity_type}s"
      collection = @@db.collection(collection_name)
      
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


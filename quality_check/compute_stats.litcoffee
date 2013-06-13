Compute quality of the crawls

The modules we need

    mongoose = require 'mongoose'
    config   = require 'config'

      
Let's do it

Our map function  
We want results for the whole thing, plus on each stylesheet

    mapR = () -> 
      key = 
        site :    @site_name
        version : @version
        crawl   : @crawl_timestamp
      emit key, @

We compute some key metrics
How important fields are filled, and globally how it's filled

    reduceR = (prev, docs) ->
      
      result = {}

      for doc in docs
        result.count = 0 if not result.count?

        result.count += 1
        for k, v of doc
          unless k == "_id"
            result[k] = 0 if not result[k]?
            result[k] += 1 if v?

      result

Execute our queries on the products collection

    mapReduceQuery =
      mapreduce : 'products'
      map       : "#{mapR}"
      reduce    : "#{reduceR}"
      out       : "quality"

    computeQuality = (params, done) -> 
      mongoose.connection.db.executeDbCommand mapReduceQuery, (err, res) ->
        console.error err, res 
        done err, res

Let's run the thing

    main = () -> mongoose.connect config.mongo, () -> computeQuality {}, () -> process.exit()
    main()

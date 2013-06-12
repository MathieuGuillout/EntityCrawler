Compute quality of the crawls

The modules we need

    mongoose = require 'mongoose'
    config   = require 'config'

      
Let's do it

Our map function  
We want results for the whole thing, plus on each stylesheet

    mapR = () -> 
      emit 'test', 1

We compute some key metrics
How important fields are filled, and globally how it's filled

    reduceR = (prev, doc) ->
      prev.test += 1

Execute our queries on the products collection

    computeQuality = (params, done) ->
      mongoose.connection.db.executeDbCommand
        mapreduce : 'products'
        map : mapR.toString()
        reduce : reduceR.toString()
        out : "quality"
      , (err, ret) ->
        console.log(err) if err?
        console.log ret
        done()

Let's run the thing

    main = () -> mongoose.connect config.mongo, () -> computeQuality {}, () -> process.exit()
    main()

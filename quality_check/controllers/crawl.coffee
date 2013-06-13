mongoose = require 'mongoose'
_        = require 'underscore'


list = (params, done) -> 
  db_conn = mongoose.connection.db

  db_conn.collection 'quality', (err, collection) ->

    collection.find({}).toArray (err, results) ->
      columns = []
      for result in results
        for key, val of result.value
          columns.push(key) if not columns.indexOf(key) >= 0

      results = results.map (res) -> _.extend res.value, res._id
      done err, 
        crawls : results
        fields : columns.sort()


module.exports = 
  list : list

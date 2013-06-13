config      = require 'config'
bf          = require 'barefoot'
crawl       = require './controllers/crawl'

methods = {}


methods.applyTo = (app) ->

  # PAGES
  app.get  '/', bf.webPage("index", crawl.list)


module.exports = methods

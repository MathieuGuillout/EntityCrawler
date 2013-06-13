config      = require 'config'
bf          = require 'barefoot'

methods = {}


methods.applyTo = (app) ->

  # PAGES
  app.get  '/', bf.webPage "index"


module.exports = methods

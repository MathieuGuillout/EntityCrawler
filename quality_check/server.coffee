# DEPENDENCIES
express      = require 'express'
mongoose     = require 'mongoose'
config       = require 'config'
_            = require 'underscore'
moment       = require 'moment'
routes       = require './routes'

# CREATE A WEB SERVER
app = express()

# CONNECTION TO THE DB 
mongoose.connect config.mongo

#To allow cross origin calls from another web page
allowCrossDomain = (req, res, next) ->
  res.header 'Access-Control-Allow-Origin', "*"
  res.header 'Access-Control-Allow-Credentials', true
  res.header 'Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS'
  res.header 'Access-Control-Allow-Headers', 'Content-Type'
  res.header "Access-Control-Allow-Headers", "X-Requested-With"
  next()

app.locals.moment = require 'moment'

# WEB SERVER CONFIGURATION 
app.configure () ->
  app.set 'views', "#{__dirname}/views"
  app.set 'view engine', 'jade'

  app.use express.static "#{__dirname}/public"
  app.use express.cookieParser()
  app.use express.bodyParser()

  app.use allowCrossDomain
  app.use app.router

# ERROR HANDLING 
app.configure 'development', () ->
  app.use express.errorHandler({dumpExceptions : true, showStack : true})

app.configure 'production', () ->
  app.use express.errorHandler()

# APPLY ALL ROUTE DEFINITIONS
app = routes.applyTo app


# STARTING THE WEB SERVER
app.listen config.port

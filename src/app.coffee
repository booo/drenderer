kue = require "kue"
kue.app.listen 3333

jobs = kue.createQueue()

redis = require "redis"

rclient = redis.createClient()
nMemcached = require "memcached"
memcached = new nMemcached "localhost:11211"

express = require "express"


app = express.createServer()

app.use app.router

app.param "z", (req, res, next, z) ->
  switch z
    when 0 then req.timeout = 1000
    else req.ttl = 1000
  next()


activeJobs = {}

app.get "/:style/:z/:x/:y.png", (req, res, next) ->
  #console.log req.url

  key = "#{req.params.style}/#{req.params.z}/#{req.params.x}/#{req.params.y}"

  tile =
    title: key
    z: req.params.z
    x: req.params.x
    y: req.params.y
    style: req.params.style
    ttl: req.ttl


  if activeJobs[key]
    activeJobs[key].on "complete", ->
      memcached.get key, (error, renderedTile) ->
        #console.log renderedTile
      #rclient.get "#{tile.style}/#{tile.z}/#{tile.x}/#{tile.y}", (error, renderedTile) ->
        if error
          next error
        else if renderedTile
          #renderedTile = JSON.parse renderedTile
          res.send (new Buffer renderedTile.data, "base64"), { "Content-Type": "image/png"}, 200
        else
          next()
  else
    memcached.get key, (error, renderedTile) ->
      if error
        next error
      else if renderedTile
        #console.log renderedTile
        #renderedTile = JSON.parse renderedTile
        res.send (new Buffer renderedTile.data, "base64"), { "Content-Type": "image/png"}, 200

      else

        job = (jobs.create 'tile', tile).save()
        activeJobs[key] = job
        job.on "failed", ->
          delete activeJobs[key]
          res.writeHead 500
          console.log "Job failed..."
          res.end()
        job.on "complete", ->
          delete activeJobs[key]
          #rclient.get "#{tile.style}/#{tile.z}/#{tile.x}/#{tile.y}", (error, renderedTile) ->
          memcached.get key, (error, renderedTile) ->
            if error
              next error
            else if renderedTile
              #renderedTile = JSON.parse renderedTile
              #console.log renderedTile
              res.send (new Buffer renderedTile.data, "base64"), { "Content-Type": "image/png"}, 200
            else
              console.log "bla"
              next()


getTileFromStore = (key, fn) ->

  memcached.get key, (error, result) ->
    fn(error, result)

app.listen 3000

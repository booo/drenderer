kue = require "kue"
jobs = kue.createQueue()

path = require "path"
redis = require "redis"
rclient = redis.createClient()

mapnik = require "mapnik"
mappool = require "../node_modules/mapnik/lib/pool"
SphericalMercator = require "sphericalmercator"
mercator = new SphericalMercator()

proj4 = "+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +wktext +no_defs +over"

projection = new mapnik.Projection proj4


# map pool with 5 maps
maps = mappool.create 5

aquire = (id, options, callback) ->
  methods=
    create: (cb) ->
      obj = new mapnik.Map (options.width || 256), (options.height || 256)
      obj.load id, {strict:true}, (error, obj) ->
        if error then callback error, null
        if options.buffer_size then obj.buffer_size options.buffer_size
        cb obj
    destroy: (obj) ->
      obj.clear()
      delete obj

  maps.acquire id, methods, (obj) ->
    callback null, obj

#process with 5 jobs
jobs.process "tile", 5, (job, done) ->
  #console.log "Started work"
  tile = job.data

  bbox = projection.forward mercator.bbox tile.x, tile.y, tile.z, false, false
  map = new mapnik.Map 256, 256, proj4
  stylePath = path.join __dirname, "../styles/#{tile.style}.xml"
  aquire stylePath, {}, (error, map) ->
    if error
      done error
    else
      im = new mapnik.Image map.width, map.height
      map.extent = bbox

      map.render im, (error, im) ->
        maps.release stylePath, map
        if error
          done error
        else
          tile.data = (im.encodeSync "png").toString("base64")
          #console.log tile
          key = "#{tile.style}/#{tile.z}/#{tile.x}/#{tile.y}"
          rclient.set key, (JSON.stringify tile), (error, result)->
            if error then console.log error
            rclient.expire key, tile.ttl, (error, result) ->
              if error then console.log error
            done()


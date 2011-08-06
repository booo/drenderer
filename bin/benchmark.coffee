#!/usr/bin/env coffee
r = require "mersenne"

s = require "superagent"
async = require "async"
get = require "get"

createRequests = ->
  requests = []
  for i in [1..1000]
    requests.push (callback) ->
      z = Math.floor r.rand 19
      x = Math.floor r.rand Math.pow 2, z
      y = Math.floor r.rand Math.pow 2, z
      (new get "http://localhost:3000/world/#{z}/#{x}/#{y}.png").asString (error, data) ->
        if error then console.log error
        callback null, 1
  requests

parallel = []
for i in [1..10]
  parallel.push (callback) ->
    async.series createRequests(), (error, results) ->
      async.reduce results, 0, ((memo, item, next) ->
        next null, memo + item), (error, result) ->
          console.log result

async.parallel parallel, (error, results) ->
  console.log "finished"

#s.get "http://localhost:3000/world/#{10}/#{10}/#{10}.png", (res) ->
#  console.log "completed 1"
#s.get "http://localhost:3000/world/#{10}/#{10}/#{10}.png", (res) ->
#  console.log "completed 2"

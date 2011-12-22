# Redmine API

HTTP = require('http')
URL = require('url')
QUERY = require('querystring')

class Redmine
  @logger = console
  
  constructor: (url, token) ->
    @url = url
    @token = token
  
  log: (message, severity = null) ->
    Redmine.logger.log message if Redmine.logger?
  
  Users: (params, callback) ->
    @get "/users.json", params, callback

  User: (id) ->
    
    show: (callback) =>
      @get "/users/#{id}.json", {}, callback
  
  Projects: (params, callback) ->
    @get "/projects.json", params, callback
  
  Issues: (params, callback) ->
    @get "/issues.json", params, callback
  
  Issue: (id) ->

    show: (params, callback) =>
      @get "/issues/#{id}.json", params, callback
      
    update: (attributes, callback) =>
      @put "/issues/#{id}.json", {issue: attributes}, callback
  
# private

  get: (path, params, callback) ->
    path = "#{path}?#{QUERY.stringify params}" if params?
    @request "GET", path, null, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  put: (path, body, callback) ->
    @request "PUT", path, body, callback
  
  # from the campfire adapter :)
  request: (method, path, body, callback) ->
    headers =
      "Content-Type": "application/json"
      "X-Redmine-API-Key": @token
    
    endpoint = URL.parse(@url)  
    
    options =
      "host"   : endpoint.hostname
      "path"   : "#{endpoint.pathname}#{path}"
      "method" : method
      "headers": headers
        
    if method is "POST" or method is "PUT"
      if typeof(body) isnt "string"
        body = JSON.stringify body

      options.headers["Content-Length"] = body.length

    request = HTTP.request options, (response) ->
      data = ""

      response.on "data", (chunk) ->
        data += chunk

      response.on "end", ->
        switch response.statusCode
          when 200
            try
              callback null, JSON.parse(data)
            catch err
              callback null, data or { }
          when 401
            throw new Error "401: Authentication failed."
          else
            @log "Code: #{response.statusCode}"
            callback response.statusCode, null

      response.on "error", (err) ->
        @log "Redmine response error: #{err}"
        callback err, null

    if method is "POST" or method is "PUT"
      request.end(body, 'binary')
    else
      request.end()

    request.on "error", (err) ->
      @log "Redmine request error: #{err}"
      callback err, null
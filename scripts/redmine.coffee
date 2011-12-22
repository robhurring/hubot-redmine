# Basic redmine API mapping
# 
#   heroku config:add HUBOT_REDMINE_BASE_URL="http://redmine.your-server.com"
#   heroku config:add HUBOT_REDMINE_TOKEN="your api token here"
#
# (redmine|show) me <ticket-id>    - Show the ticket status
# assign <ticket-id> to <user-first-name>   - Assign the ticket to the user (searches login or firstname)
# update <ticket-id> with "<note>"  - Adds a note to the ticket

module.exports = (robot) ->
  redmine = new Redmine

  robot.respond /update (?:ticket )?(?:#)?(\d+)(?:\s*with\s*)?(?:[-:,])? (?:"?([^"]+)"?)/, (msg) ->
    [id, note] = msg.match[1..2]
    
    attributes =
      "notes": "#{msg.message.user.name}: #{note}"
    
    redmine.Issue(id).update attributes, (err, data) ->
      if err?
        msg.reply "Couldn't update this ticket, sorry :("
      else
        msg.reply "Done! Updated ##{id} with \"#{note}\""

  # Robot assign <ticket> to <user>
  robot.respond /assign (?:ticket)?(?: #)?(\d+) to (\w+)/, (msg) ->
    [id, userName] = msg.match[1..2]
    
    redmine.Users name:userName, (err, data) ->
      unless data?
        msg.reply "Couldn't find any users with the name \"#{userName}\""
        return false
      
      # try to resolve the user using login/firstname -- take the first result (hacky)
      user = resolveUsers(userName, data.users)[0]
      
      # get our issue
      redmine.Issue(id).update assigned_to_id: user.id, (err, data) ->
        if err?
          msg.reply "There was an error assigning this ticket."
        else
          msg.reply "Assigned ##{id} to #{user.firstname}."

  # Robot redmine me <ticket>
  robot.respond /(?:redmine|show)(?: me)? (?:#)?(\d+)/, (msg) ->
    id = msg.match[1]

    redmine.Issue(id).show (err, data) ->
      unless data?
        msg.send "Issue ##{id} couldn't be found."
        return false
      
      issue = data.issue
      
      _ = []
      _.push "\n[#{issue.priority.name}] #{issue.tracker.name} ##{id} (#{issue.status.name})"
      _.push "Assigned: #{issue.assigned_to.name} (from #{issue.author.name})"
      _.push "Subject: #{issue.subject}"
      _.push "\n#{issue.description}"
      msg.reply _.join "\n"

# Helpers

resolveUsers = (name, data) ->
    name = name.toLowerCase();

    # try matching login
    found = data.filter (user) -> user.login.toLowerCase() == name
    return found if found.length == 1

    # try first name
    found = data.filter (user) -> user.firstname.toLowerCase() == name
    return found if found.length == 1
    
    # give up
    data
  
# Redmine API

HTTP = require('http')
URL = require('url')
QUERY = require('querystring')

class Redmine
  @url = process.env.HUBOT_REDMINE_BASE_URL
  @token = process.env.HUBOT_REDMINE_TOKEN
  @logger = console
  
  Users: (params, callback) ->
    @get "/users.json", params, callback

  User: (id) ->
    self = @
    
    show: (callback) ->
      self.get "/users/#{id}.json", {}, callback
  
  Projects: (params, callback) ->
    @get "/projects.json", params, callback
  
  Issues: (params, callback) ->
    @get "/issues.json", params, callback
  
  Issue: (id) ->
    self = @

    show: (callback) -> 
      self.get "/issues/#{id}.json", {}, callback
      
    update: (attributes, callback) ->
      self.put "/issues/#{id}.json", {issue: attributes}, callback
  
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
      "X-Redmine-API-Key": Redmine.token
    
    endpoint = URL.parse(Redmine.url)  
    
    options =
      "host"   : endpoint.hostname
      "path"   : "#{endpoint.pathname}#{path}"
      "method" : method
      "headers": headers
        
    if method is "POST" || method is "PUT"
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
            Redmine.logger.log "Code: #{response.statusCode}"
            callback response.statusCode, null

      response.on "error", (err) ->
        Redmine.logger.log "Redmine response error: #{err}"
        callback err, null

    if method is "POST" || method is "PUT"
      request.end(body, 'binary')
    else
      request.end()

    request.on "error", (err) ->
      Redmine.logger.log "Redmine request error: #{err}"
      callback err, null
# Basic redmine API mapping
# 
#   heroku config:add HUBOT_REDMINE_BASE_URL="http://redmine.your-server.com"
#   heroku config:add HUBOT_REDMINE_TOKEN="your api token here"
#
# (redmine|show) me <ticket-id>    - Show the ticket status
# show my|user's tickets    - Show your tickets or another user's tickets
# assign <ticket-id> to <user-first-name>   - Assign the ticket to the user (searches login or firstname)
# update <ticket-id> with "<note>"  - Adds a note to the ticket

module.exports = (robot) ->
  redmine = new Redmine(process.env.HUBOT_REDMINE_BASE_URL, process.env.HUBOT_REDMINE_TOKEN)
  
  # Robot show <my|user's> [redmine] tickets
  robot.respond /show (?:my|(\w+\'s)) (?:redmine )?tickets/, (msg) ->
    userMode = true
    firstName = 
      if msg.match[1]?
        userMode = false
        msg.match[1].replace(/\'.+/, '')
      else
        msg.message.user.name.split(/\s/)[0]
        
    redmine.Users name:firstName, (err,data) ->
      unless data.total_count > 0
        msg.reply "Couldn't find any users with the name \"#{firstName}\""
        return false
        
      user = resolveUsers(firstName, data.users)[0]
      
      params = 
        "assigned_to_id": user.id
        "limit": 25,
        "status_id": "open"
        "sort": "priority:desc",

      redmine.Issues params, (err, data) ->
        if err?
          msg.reply "Couldn't get a list of tickets for you!"
        else
          _ = []

          if userMode
            _.push "You have #{data.total_count} issue(s)."
          else
            _.push "#{user.firstname} has #{data.total_count} issue(s)."
            
          for issue in data.issues
            do (issue) ->
              _.push "\n[#{issue.tracker.name} - #{issue.priority.name} - #{issue.status.name}] ##{issue.id}: #{issue.subject}"
          
          msg.reply _.join "\n"
  
  # Robot update <ticket> with "<note>"
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
      unless data.total_count > 0
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
    
    params = 
      "include": "journals"
    
    redmine.Issue(id).show params, (err, data) ->
      unless data?
        msg.send "Issue ##{id} couldn't be found."
        return false
      
      issue = data.issue
      
      _ = []
      _.push "\n[#{issue.project.name} - #{issue.priority.name}] #{issue.tracker.name} ##{id} (#{issue.status.name})"
      _.push "Assigned: #{issue.assigned_to.name} (from #{issue.author.name})"
      _.push "Subject: #{issue.subject}"
      _.push "\n#{issue.description}"

      # journals
      _.push "\n" + Array(10).join('-') + '8<' + Array(40).join('-') + "\n"
      for journal in issue.journals
        do (journal) ->
          if journal.notes? and journal.notes != ""
            date = formatDate journal.created_on, 'mm/dd/yyyy (hh:ii ap)'
            _.push "#{journal.user.name} on #{date}:"
            _.push "    #{journal.notes}\n"
      
      msg.reply _.join "\n"

# Helpers

formatDate = (dateStamp, fmt = 'mm/dd/yyyy at hh:ii ap') ->
  d = new Date(dateStamp)
  
  # split up the date
  [m,d,y,h,i,s,ap] = 
    [d.getMonth() + 1, d.getDate(), d.getFullYear(), d.getHours(), d.getMinutes(), d.getSeconds(), 'AM']
  
  # leadig-0 minutes
  i = "0#{i}" if i < 10

  # adjust hours
  if h > 12
    h = h - 12 
    ap = "PM"
  
  # ghetto fab!
  fmt
    .replace(/mm/, m)
    .replace(/dd/, d)
    .replace(/yyyy/, y)
    .replace(/hh/, h)
    .replace(/ii/, i)
    .replace(/ap/, ap)
  

# try to find the user matching on login or firstname
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
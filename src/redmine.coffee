# Description:
#   Showing of redmine issuess via the REST API.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_REDMINE_BASE_URL - URL to your Redmine install
#   HUBOT_REDMINE_TOKEN - API key for your selected user
#   HUBOT_REDMINE_MENTION_REGEX - Listen for this pattern and link to Redmine tickets when heard (default '/RM#(\d+)/')
#   HUBOT_REDMINE_MENTION_MATCH - Index of matched capture from HUBOT_REDMINE_MENTION_REGEX (default 1)
#   HUBOT_REDMINE_MENTION_IGNORE_USERS - Comma-separated list of users to ignore
#   HUBOT_REDMINE_SEARCH_LIMIT - Maximum search results to show for "redmine search", default is 10
#
# Commands:
#   hubot (redmine|show) me <issue-id> - Show the issue status
#   hubot starting <issue-id> - Set the issue status, Defaults to "In Progress"
#   hubot show (my|user's) issues - Show your issues or another user's issues
#   hubot assign <issue-id> to <user-first-name> ["notes"]  - Assign the issue to the user (searches login or firstname)
#   hubot update <issue-id> with "<note>"  - Adds a note to the issue
#   hubot add <hours> hours to <issue-id> ["comments"]  - Adds hours to the issue with the optional comments
#   hubot add issue to "<project>" [tracker <id>] with "<subject>"  - Add issue to specific project
#   hubot link me <issue-id> - Returns a link to the redmine issue
#   hubot set <issue-id> to <int>% ["comments"] - Updates an issue and sets the percent done
#   hubot redmine search <query> - Search for a particular issue, wiki page, etc.
#

QUERY = require('querystring')
Redmine = require('node-redmine')

module.exports = (robot) ->
  # Ensure configuration variables are set
  unless process.env.HUBOT_REDMINE_BASE_URL?
    robot.logger.error 'HUBOT_REDMINE_BASE_URL configuration variable missing.'
    return
  unless process.env.HUBOT_REDMINE_TOKEN?
    robot.logger.error 'HUBOT_REDMINE_TOKEN configuration variable missing.'
    return

  # Initialize Redmine connection
  try
    redmine = new Redmine process.env.HUBOT_REDMINE_BASE_URL, { apiKey: process.env.HUBOT_REDMINE_TOKEN }
  catch err
    robot.logger.error err
    return
  
  # Robot link me <issue>
  robot.respond /link me (?:issue )?(?:#)?(\d+)/i, (msg) ->
    id = msg.match[1]
    msg.reply "#{process.env.HUBOT_REDMINE_BASE_URL}/issues/#{id}"

  # Robot set <issue> to <percent>% ["comments"]
  robot.respond /set (?:issue )?(?:#)?(\d+) to (\d{1,3})%?(?: "?([^"]+)"?)?/i, (msg) ->
    [id, percent, userComments] = msg.match[1..3]
    percent = parseInt percent

    if userComments?
      notes = "#{msg.message.user.name}: #{userComments}"
    else
      notes = "Ratio set by: #{msg.message.user.name}"

    attributes =
      "notes": notes
      "done_ratio": percent

    redmine.update_issue id, attributes, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      msg.reply "Set ##{id} to #{percent}%"

  # Robot add <hours> hours to <issue_id> ["comments for the time tracking"]
  robot.respond /add (\d{1,2}) hours? to (?:issue )?(?:#)?([+-]?([0-9]*[.])?[0-9]+)(?: "?([^"]+)"?)?/i, (msg) ->
    [hours, id, userComments] = msg.match[1..3]

    if userComments?
      comments = "#{msg.message.user.name}: #{userComments}"
    else
      comments = "Time logged by: #{msg.message.user.name}"

    attributes =
      "issue_id": id
      "hours": hours
      "comments": comments

    redmine.create_time_entry attributes, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      msg.reply "Your time was logged"

  # Robot show <my|user's> [redmine] issues
  robot.respond /show @?(?:my|(\w+\s?'?s?)) (?:redmine )?issues/i, (msg) ->
    userMode = true
    firstName =
      if msg.match[1]?
        userMode = false
        msg.match[1].replace(/\'.+/, '').trim()
      else
        msg.message.user.name.split(/\s/)[0]

    redmine.users name:firstName, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      unless data.total_count > 0
        msg.reply "Couldn't find any users with the name \"#{firstName}\""
        return false

      user = resolveUsers(firstName, data.users)[0]

      params =
        "assigned_to_id": user.id
        "limit": 10,
        "status_id": "open"
        "sort": "priority:desc",

      redmine.issues params, (err, data) ->
        if err?
          robot.logger.error err
          return msg.reply "Couldn't get a list of issues for you!"

        _ = []

        if userMode
          _.push "You have #{data.total_count} issue(s)."
        else
          _.push "#{user.firstname} has #{data.total_count} issue(s) and limiting to 10 issues here. :) "

        for issue in data.issues
          do (issue) ->
            _.push "\n[#{issue.tracker.name} - #{issue.priority.name} - #{issue.status.name}] ##{issue.id}: #{issue.subject}"

        msg.reply _.join "\n"

  # Robot update <issue> with "<note>"
  robot.respond /update (?:issue )?(?:#)?(\d+)(?:\s*with\s*)?(?:[-:,])? (?:"?([^"]+)"?)/i, (msg) ->
    [id, note] = msg.match[1..2]

    attributes =
      "notes": "#{msg.message.user.name}: #{note}"

    redmine.update_issue id, attributes, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      msg.reply "Done! Updated ##{id} with \"#{note}\""

  # Robot starting <issue> <status>
  robot.respond /starting (?:issue )?(?:#)?(\d+) ?(?:([^*]+)?)?/i, (msg) ->
    [id, status] = msg.match[1..2]

    if status?
      if status.match(/^New/i)
        status_id = 1
      else if status.match(/Progress/i)
        status_id = 2
      else if status.match(/Resolved/i)
        status_id = 3
      else if status.match(/Feedback/i)
        status_id = 4
      else if status.match(/Closed/i)
        status_id = 5
      else if status.match(/Rejected/i)
        status_id = 6
      else
        status_id = 2
    else
      status = "In Progress"
      status_id = 2

    attributes =
      "status_id": "#{status_id}"

    redmine.update_issue id, attributes, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      msg.reply "Done! Issue id ##{id} is now set to status '#{status}'"

  # Robot add issue to "<project>" [tracker <id>] with "<subject>"
  robot.respond /add (?:issue )?(?:\s*to\s*)?(?:"?([^" ]+)"? )(?:tracker\s)?(\d+)?(?:\s*with\s*)("?([^"]+)"?)/i, (msg) ->
    [project_id, tracker_id, subject] = msg.match[1..3]

    attributes =
      "project_id": "#{project_id}"
      "subject": "#{subject}"

    if tracker_id?
      attributes =
        "project_id": "#{project_id}"
        "subject": "#{subject}"
        "tracker_id": "#{tracker_id}"

    redmine.create_issue attributes, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      msg.reply "Done! Added issue #{data.id} with \"#{subject}\""

  # Robot assign <issue> to <user> ["note to add with the assignment]
  robot.respond /assign (?:issue )?(?:#)?(\d+) to (\w+)(?: "?([^"]+)"?)?/i, (msg) ->
    [id, userName, note] = msg.match[1..3]

    redmine.users name:userName, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      unless data.total_count > 0
        msg.reply "Couldn't find any users with the name \"#{userName}\""
        return false

      # try to resolve the user using login/firstname -- take the first result (hacky)
      user = resolveUsers(userName, data.users)[0]

      attributes =
        "assigned_to_id": user.id

      # allow an optional note with the re-assign
      attributes["notes"] = "#{msg.message.user.name}: #{note}" if note?

      # get our issue
      redmine.update_issue id, attributes, (err, data) ->
        if err
          robot.logger.error err
          return msg.reply err

        msg.reply "Assigned ##{id} to #{user.firstname}."

  # Robot redmine me <issue>
  robot.respond /(?:redmine|show)(?: me)? (?:issue )?(?:#)?(\d+)/i, (msg) ->
    id = parseInt(msg.match[1], 10)

    params =
      include: "journals"

    redmine.get_issue_by_id id, params, (err, data) ->
      issue = data.issue
      robot.logger.debug issue
      _ = []
      _.push "\n[#{issue.project.name} - #{issue.priority.name}] #{issue.tracker.name} ##{issue.id} (#{issue.status.name})"
      _.push "Assigned: #{issue.assigned_to?.name ? 'Nobody'} (opened by #{issue.author.name})"
      if issue.status.name.toLowerCase() != 'new'
         _.push "Progress: #{issue.done_ratio}% (#{issue.spent_hours} hours)"
      _.push "Subject: #{issue.subject}"
      _.push "\n#{issue.description}"

      # journals
      if issue.journals?
        _.push "\n" + Array(10).join('-') + '8<' + Array(50).join('-') + "\n"
        for journal in issue.journals
          do (journal) ->
            if journal.notes? and journal.notes != ""
              date = formatDate journal.created_on, 'mm/dd/yyyy (hh:ii ap)'
              _.push "#{journal.user.name} on #{date}:"
              _.push "    #{journal.notes}\n"

      msg.reply _.join "\n"

  # Robot redmine search <query>
  robot.respond /redmine search (.*)/i, (msg) ->
    params =
      q: msg.match[1]
      limit: process.env.HUBOT_REDMINE_SEARCH_LIMIT || 10

    # Search endpoint Not available in node-redmine@0.2.1
    robot.http("#{process.env.HUBOT_REDMINE_BASE_URL}/search.json?#{QUERY.stringify(params)}")
      .header('x-redmine-api-key', process.env.HUBOT_REDMINE_TOKEN)
      .get() (err, res, body) ->
        if err?
          robot.logger.error err
          return msg.reply err

        try
          data = JSON.parse(body)
        catch err
          robot.logger.error err
          return msg.reply err

        if data.total_count > 0
          _ = []
          for result in data.results
            _.push "#{result.title} - #{result.url}"
          if data.total_count > data.limit
            _.push "More results: #{process.env.HUBOT_REDMINE_BASE_URL}/search?q=#{params.q}"
          msg.reply _.join "\n"
        else
          msg.reply "No search results for #{params.q}"

  # Chime in on ticket mentions.
  # Default requires double-backquote here but not in shell.
  mentions_regex = RegExp process.env.HUBOT_REDMINE_MENTION_REGEX or '#(\\d+)'
  robot.hear mentions_regex, (msg) ->
    id = parseInt(msg.match[1], 10)
    # Ignore certain users, like Redmine plugins.
    ignoredUsers = process.env.HUBOT_REDMINE_MENTION_IGNORE_USERS or ""
    if isNaN(id) or id == 0 or msg.message.user.name in ignoredUsers.split(',')
      return

    params = {}

    redmine.get_issue_by_id id, params, (err, data) ->
      if err
        robot.logger.error err
        return msg.reply err

      issue = data.issue
      url = "#{process.env.HUBOT_REDMINE_BASE_URL}/issues/#{id}"
      # Could be a template string for configurability?
      msg.send "#{issue.tracker.name} ##{issue.id} (#{issue.project.name}): #{issue.subject} (#{issue.status.name}) [#{issue.priority.name}]"
      msg.send "#{url}"

  # simple ghetto fab date formatter this should definitely be replaced, but didn't want to
  # introduce dependencies this early
  #
  # dateStamp - any string that can initialize a date
  # fmt - format string that may use the following elements
  #       mm - month
  #       dd - day
  #       yyyy - full year
  #       hh - hours
  #       ii - minutes
  #       ss - seconds
  #       ap - am / pm
  #
  # returns the formatted date
  formatDate = (dateStamp, fmt = 'mm/dd/yyyy at hh:ii ap') ->
    d = new Date(dateStamp)

    # split up the date
    [m,d,y,h,i,s,ap] =
      [d.getMonth() + 1, d.getDate(), d.getFullYear(), d.getHours(), d.getMinutes(), d.getSeconds(), 'AM']

    # leadig 0s
    i = "0#{i}" if i < 10
    s = "0#{s}" if s < 10

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
      .replace(/ss/, s)
      .replace(/ap/, ap)

  # tries to resolve ambiguous users by matching login or firstname
  # redmine's user search is pretty broad (using login/name/email/etc.) so
  # we're trying to just pull it in a bit and get a single user
  #
  # name - this should be the name you're trying to match
  # data - this is the array of users from redmine
  #
  # returns an array with a single user, or the original array if nothing matched
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

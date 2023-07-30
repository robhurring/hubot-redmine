# Description:
#   Interact with a Redmine instance.
#
# Dependencies:
#   None
#
# Commands:
#   hubot redmine show <issue-id> - Show the issue status
#   hubot redmine starting <issue-id> - Set the issue status, Defaults to "In Progress"
#   hubot redmine show (my|user's) issues - Show your issues or another user's issues
#   hubot redmine assign <issue-id> to <user-first-name> ["notes"]  - Assign the issue to the user (searches login or firstname)
#   hubot redmine update <issue-id> with "<note>"  - Adds a note to the issue
#   hubot redmine add <hours> hours to <issue-id> ["comments"]  - Adds hours to the issue with the optional comments
#   hubot redmine add issue to "<project>" [tracker <id>] with "<subject>"  - Add issue to specific project
#   hubot redmine link me <issue-id> - Returns a link to the redmine issue
#   hubot redmine set <issue-id> to <int>% ["comments"] - Updates an issue and sets the percent done
#   hubot redmine redmine search <query> - Search for a particular issue, wiki page, etc.
#

QUERY = require('querystring')
Redmine = require('axios-redmine')

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
  robot.respond /(?:redmine|rm) link me (?:issue )?(?:#)?(\d+)/i, (msg) ->
    id = msg.match[1]
    msg.reply "#{process.env.HUBOT_REDMINE_BASE_URL}/issues/#{id}"

  # Robot set <issue> to <percent>% ["comments"]
  robot.respond /(?:redmine|rm) set (?:issue )?(?:#)?(\d+) to (\d{1,3})%?(?: "?([^"]+)"?)?/i, (msg) ->
    [id, percent, userComments] = msg.match[1..3]
    percent = parseInt percent

    if userComments?
      notes = "#{msg.message.user.name}: #{userComments}"
    else
      notes = "Ratio set by: #{msg.message.user.name}"

    attributes =
      "notes": notes
      "done_ratio": percent

    redmine.update_issue(id, attributes)
      .then (response) ->
        robot.logger.debug response
        msg.reply "Set ##{id} to #{percent}%"
      .catch (err) ->
        robot.logger.error err
        msg.reply err

  # Robot add <hours> hours to <issue_id> ["comments for the time tracking"]
  robot.respond /(?:redmine|rm) add (\d{1,2}) hours? to (?:issue )?(?:#)?([+-]?([0-9]*[.])?[0-9]+)(?: "?([^"]+)"?)?/i, (msg) ->
    [hours, id, userComments] = msg.match[1..3]

    if userComments?
      comments = "#{msg.message.user.name}: #{userComments}"
    else
      comments = "Time logged by: #{msg.message.user.name}"

    attributes =
      "issue_id": id
      "hours": hours
      "comments": comments

    redmine.create_time_entry(attributes)
      .then (response) ->
        robot.logger.debug response
        msg.reply "Your time was logged"
      .catch (err) ->
        robot.logger.error err
        msg.reply err

  # Robot show <my|user's> [redmine] issues
  robot.respond /(?:redmine|rm) show @?(?:my|(\w+\s?'?s?)) (?:redmine )?issues/i, (msg) ->
    userMode = true
    firstName =
      if msg.match[1]?
        userMode = false
        msg.match[1].replace(/\'.+/, '').trim()
      else
        msg.message.user.name.split(/\s/)[0]

    redmine.users name:firstName
      .then (response) ->
        unless response.data.total_count > 0
          throw new Error("Couldn't find any users with the name \"#{firstName}\"")
        return response.data.users
      .then (users) ->
        return resolveUsers(firstName, users)[0]
      .then (user) ->
        params =
          assigned_to_id: user.id
          limit: 10,
          status_id: "open"
          sort: "priority:desc",

        redmine.issues(params)
          .then (response) ->
            _ = []

            if userMode
              _.push "You have #{response.data.total_count} issue(s)."
            else
              _.push "#{user.firstname} has #{response.data.total_count} issue(s) and limiting to 10 issues here. :) "

            for issue in response.data.issues
              do (issue) ->
                _.push "\n[#{issue.tracker.name} - #{issue.priority.name} - #{issue.status.name}] ##{issue.id}: #{issue.subject}"

            msg.reply _.join "\n"
          .catch (err) ->
            robot.logger.error err
            msg.reply "Couldn't get a list of issues for you!"

      .catch (err) ->
        robot.logger.error err
        msg.reply err
      

  # Robot update <issue> with "<note>"
  robot.respond /(?:redmine|rm) update (?:issue )?(?:#)?(\d+)(?:\s*with\s*)?(?:[-:,])? (?:"?([^"]+)"?)/i, (msg) ->
    [id, note] = msg.match[1..2]

    attributes =
      "notes": "#{msg.message.user.name}: #{note}"

    redmine.update_issue id, attributes
      .then (response) ->
        robot.logger.debug response
        msg.reply "Done! Updated ##{id} with \"#{note}\""
      .catch (err) ->
        robot.logger.error err
        msg.reply err

  # Robot starting <issue> <status>
  robot.respond /(?:redmine|rm) starting (?:issue )?(?:#)?(\d+) ?(?:([^*]+)?)?/i, (msg) ->
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

    redmine.update_issue id, attributes
      .then (response) ->
        robot.logger.debug response
        msg.reply "Done! Issue id ##{id} is now set to status '#{status}'"
      .catch (err) ->
        robot.logger.error err
        msg.reply err

  # Robot add issue to "<project>" [tracker <id>] with "<subject>"
  robot.respond /(?:redmine|rm) add (?:issue )?(?:\s*to\s*)?(?:"?([^" ]+)"? )(?:tracker\s)?(\d+)?(?:\s*with\s*)("?([^"]+)"?)/i, (msg) ->
    [project_id, tracker_id, subject] = msg.match[1..3]

    attributes =
      "project_id": "#{project_id}"
      "subject": "#{subject}"

    if tracker_id?
      attributes =
        "project_id": "#{project_id}"
        "subject": "#{subject}"
        "tracker_id": "#{tracker_id}"

    redmine.create_issue attributes
      .then (response) ->
        robot.logger.debug response
        msg.reply "Done! Added issue #{response.data.id} with \"#{subject}\""
      .catch (err) ->
        robot.logger.error err
        msg.reply err

  # Robot assign <issue> to <user> ["note to add with the assignment]
  robot.respond /(?:redmine|rm) assign (?:issue )?(?:#)?(\d+) to (\w+)(?: "?([^"]+)"?)?/i, (msg) ->
    [id, userName, note] = msg.match[1..3]
    users = []
    redmine.users name:userName
      .then (response) ->
        unless response.data.total_count > 0
          throw new Error("Couldn't find any users with the name \"#{userName}\"")
        return response.data.users
      .then (users) ->
        # try to resolve the user using login/firstname -- take the first result (hacky)
        user = resolveUsers(userName, users)[0]

        attributes =
          "assigned_to_id": user.id

        # allow an optional note with the re-assign
        attributes["notes"] = "#{msg.message.user.name}: #{note}" if note?

        # get our issue
        redmine.update_issue id, attributes
          .then (response) ->
            robot.logger.debug response
            msg.reply "Assigned ##{id} to #{user.firstname}."

      .catch (err) ->
        robot.logger.error err
        msg.reply err

  # Robot redmine me <issue>
  robot.respond /(?:redmine|rm)(?: show)?(?: me)? (?:issue )?(?:#)?(\d+)/i, (msg) ->
    id = parseInt(msg.match[1], 10)

    params =
      include: "journals"

    redmine.get_issue_by_id id, params
      .then (response) ->
        robot.logger.debug response  
        issue = response.data.issue
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
  robot.respond /(?:redmine|rm) search (.*)/i, (msg) ->
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

  # Chime in on ticket mentions if enabled
  if process.env.HUBOT_REDMINE_MENTION_REGEX?
    robot.hear RegExp(process.env.HUBOT_REDMINE_MENTION_REGEX), (msg) ->
      match_index = if process.env.HUBOT_REDMINE_MENTION_MATCH then process.env.HUBOT_REDMINE_MENTION_MATCH else 1
      id = parseInt(msg.match[match_index], 10)
      # Ignore certain users, like Redmine plugins.
      ignoredUsers = process.env.HUBOT_REDMINE_MENTION_IGNORE_USERS or ""
      if isNaN(id) or id == 0 or msg.message.user.name in ignoredUsers.split(',')
        return

      params = {}

      redmine.get_issue_by_id id, params
        .then (response) ->
          robot.logger.debug response
          issue = response.data.issue
          url = "#{process.env.HUBOT_REDMINE_BASE_URL}/issues/#{id}"
          # Could be a template string for configurability?
          msg.send "#{issue.tracker.name} ##{issue.id} (#{issue.project.name}): #{issue.subject} (#{issue.status.name}) [#{issue.priority.name}]"
          msg.send "#{url}"
        .catch (err) ->
          robot.logger.error err
          return msg.reply err

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

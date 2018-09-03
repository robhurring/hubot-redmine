Helper = require('hubot-test-helper')
chai = require 'chai'
nock = require 'nock'

expect = chai.expect

helper = new Helper [
  '../src/redmine.coffee'
]

# Alter time as test runs
originalDateNow = Date.now
mockDateNow = () ->
  return Date.parse('Mon Aug 27 2018 09:07:07 GMT-0500 (CDT)')

describe 'hubot-redmine', ->
  beforeEach ->
    process.env.HUBOT_LOG_LEVEL='error'
    process.env.HUBOT_REDMINE_BASE_URL='https://redmine.example.org'
    process.env.HUBOT_REDMINE_TOKEN='foobarbaz123'
    Date.now = mockDateNow
    nock.disableNetConnect()
    @room = helper.createRoom()

  afterEach ->
    delete process.env.HUBOT_LOG_LEVEL
    delete process.env.HUBOT_REDMINE_BASE_URL
    delete process.env.HUBOT_REDMINE_TOKEN
    Date.now = originalDateNow
    nock.cleanAll()
    @room.destroy()

  # hubot (redmine|show) me <issue-id> 
  it 'returns the details of an issue', (done) ->
    nock('https://redmine.example.org')
      .get('/issues/100.json?include=journals')
      .replyWithFile(200, __dirname + '/fixtures/issues-100.json')

    selfRoom = @room
    selfRoom.user.say('alice', '@hubot redmine me 100')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', '@hubot redmine me 100']
          ['hubot', '@alice \n[Redmine - Normal] Defect #100 (Closed)\nAssigned: Nobody (opened by Damien McKenna)\nProgress: 0% (undefined hours)\nSubject: New Project - subproject list should not show archived projects\n\nThe subprojects list in the New Project editor should not list archived projects?  Either that or flag items as being\narchived, e.g. italicise the name, put a star beside it or put the name in parenthesis?']
        ]
        done()
      catch err
        done err
      return
    , 1000)


  # hubot starting <issue-id>
  it 'sets an issue to in progress', (done) ->
      nock('https://redmine.example.org')
        .intercept('/issues/100.json', 'PUT')
        .replyWithFile(200, __dirname + '/fixtures/issues-100.json')

      selfRoom = @room
      selfRoom.user.say('alice', '@hubot starting 100')
      setTimeout(() ->
        try
          expect(selfRoom.messages).to.eql [
            ['alice', '@hubot starting 100']
            ['hubot', "@alice Done! Issue id #100 is now set to status 'In Progress'"]
          ]
          done()
        catch err
          done err
        return
      , 1000)
  
  # hubot show (my|user's) issues
  it 'retrieves a list of my issues', (done) ->
      nock('https://redmine.example.org')
        .get('/users.json?name=alice')
        .replyWithFile(200, __dirname + '/fixtures/users-search.json')

      nock('https://redmine.example.org')
        .get('/issues.json?assigned_to_id=4&limit=10&status_id=open&sort=priority%3Adesc')
        .replyWithFile(200, __dirname + '/fixtures/issues-mine.json')

      selfRoom = @room
      selfRoom.user.say('alice', '@hubot show my issues')
      setTimeout(() ->
        try
          expect(selfRoom.messages).to.eql [
            ['alice', '@hubot show my issues']
            ['hubot', "@alice You have 135 issue(s).\n\n[Feature - High - New] #3506: Need ability to restrict which  role  can update/select the target version   when updating  or submitting an issue\n\n[Defect - High - New] #3578: Subversion fetch_changesets does not handle moved (root-)directories\n\n[Feature - High - New] #4714: hide \"Projects\" from the main menu for anonymous users, when there are no public projects\n\n[Defect - High - Confirmed] #13424: Demo instance\n\n[Defect - High - Reopened] #19229: redmine.org plugin page only shows latest version compatibility\n\n[Defect - High - New] #21379: Plugin author is not able to delete plugin versions\n\n[Defect - High - Confirmed] #25726: Issue details page shows default values for custom fields that aren't actually set\n\n[Defect - High - Confirmed] #28882: GDPR compliance\n\n[Patch - Normal - New] #240: views/user/edit, make password fields not-autocomplete (UI fix)\n\n[Defect - Normal - New] #668: Date input fields don't respect date format settings"]
          ]
          done()
        catch err
          done err
        return
      , 1000)

  # hubot assign <issue-id> to <user-first-name> ["notes"]
  it 'assigns an issue to another user', (done) ->
      nock('https://redmine.example.org')
        .get('/users.json?name=alice2')
        .replyWithFile(200, __dirname + '/fixtures/users-search.json')
      
      nock('https://redmine.example.org')
        .intercept('/issues/100.json', 'PUT')
        .replyWithFile(200, __dirname + '/fixtures/issues-100.json')

      selfRoom = @room
      selfRoom.user.say('alice', '@hubot assign 100 to alice2 "Take a look at this one."')
      setTimeout(() ->
        try
          expect(selfRoom.messages).to.eql [
            ['alice', '@hubot assign 100 to alice2 "Take a look at this one."']
            ['hubot', "@alice Assigned #100 to Alice."]
          ]
          done()
        catch err
          done err
        return
      , 1000)

  # hubot update <issue-id> with "<note>"
  it 'updates an issue with a note', (done) ->
    nock('https://redmine.example.org')
      .intercept('/issues/100.json', 'PUT')
      .replyWithFile(200, __dirname + '/fixtures/issues-100.json')

    selfRoom = @room
    selfRoom.user.say('alice', '@hubot update 100 with "This looks good."')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', '@hubot update 100 with "This looks good."']
          ['hubot', "@alice Done! Updated #100 with \"This looks good.\""]
        ]
        done()
      catch err
        done err
      return
    , 1000)

  # hubot add <hours> hours to <issue-id> ["comments"]
  it 'adds tracked time to an issue', (done) ->
    nock('https://redmine.example.org')
      .post('/time_entries.json')
      .replyWithFile(200, __dirname + '/fixtures/time_entry-1.json')

    selfRoom = @room
    selfRoom.user.say('alice', '@hubot add 4 hours to 1 "This is taking a while."')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', '@hubot add 4 hours to 1 \"This is taking a while.\"']
          ['hubot', "@alice Your time was logged"]
        ]
        done()
      catch err
        done err
      return
    , 1000)

  # hubot add issue to "<project>" [tracker <id>] with "<subject>"
  it 'adds a new issue to a project', (done) ->
    nock('https://redmine.example.org')
      .post('/issues.json')
      .replyWithFile(200, __dirname + '/fixtures/issues-new.json')

    selfRoom = @room
    selfRoom.user.say('alice', '@hubot add issue to "super-important-project" with "Broken image on home page"')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', '@hubot add issue to "super-important-project" with "Broken image on home page"']
          ['hubot', "@alice Done! Added issue 100 with \"\"Broken image on home page\"\""]
        ]
        done()
      catch err
        done err
      return
    , 1000)

  # hubot link me <issue-id>
  it 'returns a link to an issue', (done) ->
    selfRoom = @room
    selfRoom.user.say('alice', '@hubot link me 100')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', '@hubot link me 100']
          ['hubot', "@alice https://redmine.example.org/issues/100"]
        ]
        done()
      catch err
        done err
      return
    , 1000)

  # hubot set <issue-id> to <int>% ["comments"]
  it 'updates an issue with a percentage complete', (done) ->
    nock('https://redmine.example.org')
      .intercept('/issues/100.json', 'PUT')
      .replyWithFile(200, __dirname + '/fixtures/issues-100.json')

    selfRoom = @room
    selfRoom.user.say('alice', '@hubot set 100 to 95% "Almost done!"')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', "@hubot set 100 to 95% \"Almost done!\""]
          ['hubot', "@alice Set #100 to 95%"]
        ]
        done()
      catch err
        done err
      return
    , 1000)

  # hubot redmine search <query>
  it 'searches for an issue', (done) ->
    nock('https://redmine.example.org')
      .get('/search.json?q=bug&limit=10')
      .replyWithFile(200, __dirname + '/fixtures/search.json')

    selfRoom = @room
    selfRoom.user.say('alice', '@hubot redmine search bug')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', '@hubot redmine search bug']
          ['hubot', '@alice Revision dfa1d19e (superimportantproject-rails): Merge pull request #277 from bobjones/bug/fix-nan-calendar - https://redmine.example.org/projects/superimportantproject/repository/revisions/dfa1d19e175a92f95c1262711529dc23e01feb64\nRevision e606e65e (superimportantproject-rails): Merge pull request #273 from bobjones/bug/hide-table-headers-if-none-available - https://redmine.example.org/projects/superimportantproject/repository/revisions/e606e65e68befce20bac9dd06c894ce3bb771c25\nRevision 2021f4b1 (superimportantproject-rails): Merge pull request #268 from bobjones/bug/handle-rails-cves - https://redmine.example.org/projects/superimportantproject/repository/revisions/2021f4b1abbb7d460e6e6fc3561efc15fef77517\nRevision b85780ef (superimportantproject-rails): Merge pull request #241 from bobjones/bug/240-zeroclipboard-turbolinks - https://redmine.example.org/projects/superimportantproject/repository/revisions/b85780ef120dc9a6bb6db6043f75d8f483915620\nRevision 3df9b825 (superimportantproject-rails): Merge pull request #236 from bobjones/bug/deprecated-datetime_tbd-field - https://redmine.example.org/projects/superimportantproject/repository/revisions/3df9b825fb027e327006f9fb0395315b4c8fd515\nRevision a929776e (superimportantproject-rails): Merge pull request #233 from bobjones/bug/admin-fixes - https://redmine.example.org/projects/superimportantproject/repository/revisions/a929776e42c91a2cf545913c2c0b6f8f2b3c57fb\nRevision 5ceae86f (superimportantproject-rails): Merge pull request #220 from superimportantproject/bug/user-aliases - https://redmine.example.org/projects/superimportantproject/repository/revisions/5ceae86fa3573888f56a8b062f5694c66163b7fe\nRevision 776f3148 (superimportantproject-rails): Merge pull request #208 from superimportantproject/hotfix/leak-ticket-data-alias-fix - https://redmine.example.org/projects/superimportantproject/repository/revisions/776f3148c1099eacc5826cb8a68203deaced630f\nRevision 1e3f2a26 (superimportantproject-rails): Fix data leak between groups, user alias save bug - https://redmine.example.org/projects/superimportantproject/repository/revisions/1e3f2a26db7c3726b87d80c010ea41264fe84b11\nRevision 98954942 (superimportantproject-rails): Merge pull request #193 from superimportantproject/bug/192-schedule-mailer-test - https://redmine.example.org/projects/superimportantproject/repository/revisions/98954942113f5c549e8fb8187e14ffda4047e96a\nMore results: https://redmine.example.org/search?q=bug']
        ]
        done()
      catch err
        done err
      return
    , 1000)

  it 'searches for an issue with no results', (done) ->
    nock('https://redmine.example.org')
      .get('/search.json?q=no%20results&limit=10')
      .replyWithFile(200, __dirname + '/fixtures/search-empty.json')

    selfRoom = @room
    selfRoom.user.say('alice', '@hubot redmine search no results')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', '@hubot redmine search no results']
          ['hubot', '@alice No search results for no results']
        ]
        done()
      catch err
        done err
      return
    , 1000)

  # chime in on an issue
  it 'hears an issue', (done) ->
    nock('https://redmine.example.org')
      .get('/issues/100.json')
      .replyWithFile(200, __dirname + '/fixtures/issues-100.json')

    selfRoom = @room
    selfRoom.user.say('alice', 'What about #100?')
    setTimeout(() ->
      try
        expect(selfRoom.messages).to.eql [
          ['alice', 'What about #100?']
          ['hubot', 'Defect #100 (Redmine): New Project - subproject list should not show archived projects (Closed) [Normal]']
          ['hubot', "https://redmine.example.org/issues/100"]
        ]
        done()
      catch err
        done err
      return
    , 1000)

describe 'hubot-redmine missing configuration', ->
  beforeEach ->
    process.env.HUBOT_LOG_LEVEL='error'
    Date.now = mockDateNow
    nock.disableNetConnect()
    @room = helper.createRoom()

  afterEach ->
    delete process.env.HUBOT_LOG_LEVEL
    Date.now = originalDateNow
    nock.cleanAll()
    @room.destroy()

  it 'does not register listeners if not configured properly', ->
    expect(@room.robot.responders).to.be.undefined
    
  

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
    Date.now = mockDateNow
    nock.disableNetConnect()
    @room = helper.createRoom()

  afterEach ->
    delete process.env.HUBOT_LOG_LEVEL
    delete process.env.HUBOT_REDMINE_BASE_URL
    Date.now = originalDateNow
    nock.cleanAll()
    @room.destroy()

  it 'registers a add hours to issue listener', ->
    expect(@room.robot.responders).to.contain(/add (\d{1,2}) hours? to (?:issue )?(?:#)?(\d+)(?: "?([^"]+)"?)?/i)

  it 'registers a add issue to tracker listener', ->
    expect(@room.robot.responders).to.contain(/add (?:issue )?(?:\s*to\s*)?(?:"?([^" ]+)"? )(?:tracker\s)?(\d+)?(?:\s*with\s*)("?([^"]+)"?)/i)

  it 'registers a assign issue listener', ->
    expect(@room.robot.responders).to.contain(/assign (?:issue )?(?:#)?(\d+) to (\w+)(?: "?([^"]+)"?)?/i)

  it 'registers a link me listener', ->
    expect(@room.robot.responders).to.contain(/link me (?:issue )?(?:#)?(\d+)/i)

  it 'registers a search listener', ->
    expect(@room.robot.responders).to.contain(/redmine search (.*)/i)

  it 'registers a set listener', ->
    expect(@room.robot.responders).to.contain(/set (?:issue )?(?:#)?(\d+) to (\d{1,3})%?(?: "?([^"]+)"?)?/i)

  it 'registers a show listener', ->
    expect(@room.robot.responders).to.contain(/show @?(?:my|(\w+\s?'?s?)) (?:redmine )?issues/i)

  it 'registers a show listener', ->
    expect(@room.robot.responders).to.contain(/(?:redmine|show)(?: me)? (?:issue )?(?:#)?(\d+)/i)

  it 'registers a update listener', ->
    expect(@room.robot.responders).to.contain(/update (?:issue )?(?:#)?(\d+)(?:\s*with\s*)?(?:[-:,])? (?:"?([^"]+)"?)/i)

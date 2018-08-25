chai = require 'chai'
sinon = require 'sinon'
chai.use require 'sinon-chai'

expect = chai.expect

describe 'redmine', ->
  beforeEach ->
    @robot =
      respond: sinon.spy()
      hear: sinon.spy()

    require('../src/redmine')(@robot)

  it 'registers a add hours to issue listener', ->
    expect(@robot.respond).to.have.been.calledWith(/add (\d{1,2}) hours? to (?:issue )?(?:#)?(\d+)(?: "?([^"]+)"?)?/i)

  it 'registers a add issue to tracker listener', ->
    expect(@robot.respond).to.have.been.calledWith(/add (?:issue )?(?:\s*to\s*)?(?:"?([^" ]+)"? )(?:tracker\s)?(\d+)?(?:\s*with\s*)("?([^"]+)"?)/i)

  it 'registers a assign issue listener', ->
    expect(@robot.respond).to.have.been.calledWith(/assign (?:issue )?(?:#)?(\d+) to (\w+)(?: "?([^"]+)"?)?/i)

  it 'registers a link me listener', ->
    expect(@robot.respond).to.have.been.calledWith(/link me (?:issue )?(?:#)?(\d+)/i)

  it 'registers a search listener', ->
    expect(@robot.respond).to.have.been.calledWith(/redmine search (.*)/i)

  it 'registers a set listener', ->
    expect(@robot.respond).to.have.been.calledWith(/set (?:issue )?(?:#)?(\d+) to (\d{1,3})%?(?: "?([^"]+)"?)?/i)

  it 'registers a show listener', ->
    expect(@robot.respond).to.have.been.calledWith(/show @?(?:my|(\w+\s?'?s?)) (?:redmine )?issues/i)

  it 'registers a show listener', ->
    expect(@robot.respond).to.have.been.calledWith(/(?:redmine|show)(?: me)? (?:issue )?(?:#)?(\d+)/i)

  it 'registers a update listener', ->
    expect(@robot.respond).to.have.been.calledWith(/update (?:issue )?(?:#)?(\d+)(?:\s*with\s*)?(?:[-:,])? (?:"?([^"]+)"?)/i)

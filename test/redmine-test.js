/* eslint-disable func-names */

const assert = require('assert/strict');
const {
  afterEach,
  beforeEach,
  describe,
  it,
} = require('node:test');
const nock = require('nock');

const loadScript = require('../src/redmine.js');

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const eventually = async (assertion, timeoutMs = 1000) => {
  const start = Date.now();
  let lastError;

  while ((Date.now() - start) < timeoutMs) {
    try {
      assertion();
      return;
    } catch (error) {
      lastError = error;
      // Allow async handlers/network callbacks to complete.
      // eslint-disable-next-line no-await-in-loop
      await delay(10);
    }
  }

  throw lastError;
};

const createRoom = () => {
  const responders = [];
  const listeners = [];
  const messages = [];

  const robot = {
    logger: {
      debug: () => {},
      error: () => {},
    },
    respond: (regex, callback) => {
      responders.push({ regex, callback });
    },
    hear: (regex, callback) => {
      listeners.push({ regex, callback });
    },
    responders,
  };

  loadScript(robot);

  const makeMessage = (name, match) => ({
    match,
    message: {
      user: { name },
    },
    reply: (value) => {
      messages.push(['hubot', `@${name} ${String(value)}`]);
    },
    send: (value) => {
      messages.push(['hubot', String(value)]);
    },
  });

  const runResponders = (name, text) => {
    const addressedText = text.replace(/^@?hubot[:,]?\s+/i, '');
    responders.forEach(({ regex, callback }) => {
      const match = addressedText.match(regex);
      if (match != null) {
        callback(makeMessage(name, match));
      }
    });
  };

  const runListeners = (name, text) => {
    listeners.forEach(({ regex, callback }) => {
      const match = text.match(regex);
      if (match != null) {
        callback(makeMessage(name, match));
      }
    });
  };

  return {
    robot,
    messages,
    user: {
      say(name, text) {
        messages.push([name, text]);
        runResponders(name, text);
        runListeners(name, text);
      },
    },
    destroy() {},
  };
};

describe('hubot-redmine', () => {
  beforeEach(function () {
    process.env.HUBOT_LOG_LEVEL = 'error';
    process.env.HUBOT_REDMINE_BASE_URL = 'https://redmine.example.org';
    process.env.HUBOT_REDMINE_TOKEN = 'foobarbaz123';
    nock.disableNetConnect();
    this.room = createRoom();
  });

  afterEach(function () {
    delete process.env.HUBOT_LOG_LEVEL;
    delete process.env.HUBOT_REDMINE_BASE_URL;
    delete process.env.HUBOT_REDMINE_TOKEN;
    nock.cleanAll();
    nock.enableNetConnect();
    this.room.destroy();
  });

  it('returns the details of an issue', async function () {
    nock('https://redmine.example.org')
      .get('/issues/100.json?include=journals')
      .replyWithFile(200, `${__dirname}/fixtures/issues-100.json`);

    const selfRoom = this.room;
    selfRoom.user.say('alice', '@hubot redmine me 100');

    await eventually(() => {
      assert.deepEqual(selfRoom.messages, [
        ['alice', '@hubot redmine me 100'],
        ['hubot', '@alice \n[Redmine - Normal] Defect #100 (Closed)\nAssigned: Nobody (opened by Damien McKenna)\nProgress: 0%\nSubject: New Project - subproject list should not show archived projects\n\nThe subprojects list in the New Project editor should not list archived projects?  Either that or flag items as being\narchived, e.g. italicise the name, put a star beside it or put the name in parenthesis?'],
      ]);
    });
  });

  it('sets an issue to in progress', async function () {
    nock('https://redmine.example.org')
      .intercept('/issues/100.json', 'PUT')
      .replyWithFile(200, `${__dirname}/fixtures/issues-100.json`);

    const selfRoom = this.room;
    selfRoom.user.say('alice', '@hubot redmine starting 100');

    await eventually(() => {
      assert.deepEqual(selfRoom.messages, [
        ['alice', '@hubot redmine starting 100'],
        ['hubot', "@alice Done! Issue id #100 is now set to status 'In Progress'"],
      ]);
    });
  });

  it('searches for an issue', async function () {
    nock('https://redmine.example.org')
      .get('/search.json?q=bug&limit=10')
      .replyWithFile(200, `${__dirname}/fixtures/search.json`);

    const selfRoom = this.room;
    selfRoom.user.say('alice', '@hubot redmine search bug');

    await eventually(() => {
      assert.deepEqual(selfRoom.messages, [
        ['alice', '@hubot redmine search bug'],
        ['hubot', '@alice Revision dfa1d19e (superimportantproject-rails): Merge pull request #277 from bobjones/bug/fix-nan-calendar - https://redmine.example.org/projects/superimportantproject/repository/revisions/dfa1d19e175a92f95c1262711529dc23e01feb64\nRevision e606e65e (superimportantproject-rails): Merge pull request #273 from bobjones/bug/hide-table-headers-if-none-available - https://redmine.example.org/projects/superimportantproject/repository/revisions/e606e65e68befce20bac9dd06c894ce3bb771c25\nRevision 2021f4b1 (superimportantproject-rails): Merge pull request #268 from bobjones/bug/handle-rails-cves - https://redmine.example.org/projects/superimportantproject/repository/revisions/2021f4b1abbb7d460e6e6fc3561efc15fef77517\nRevision b85780ef (superimportantproject-rails): Merge pull request #241 from bobjones/bug/240-zeroclipboard-turbolinks - https://redmine.example.org/projects/superimportantproject/repository/revisions/b85780ef120dc9a6bb6db6043f75d8f483915620\nRevision 3df9b825 (superimportantproject-rails): Merge pull request #236 from bobjones/bug/deprecated-datetime_tbd-field - https://redmine.example.org/projects/superimportantproject/repository/revisions/3df9b825fb027e327006f9fb0395315b4c8fd515\nRevision a929776e (superimportantproject-rails): Merge pull request #233 from bobjones/bug/admin-fixes - https://redmine.example.org/projects/superimportantproject/repository/revisions/a929776e42c91a2cf545913c2c0b6f8f2b3c57fb\nRevision 5ceae86f (superimportantproject-rails): Merge pull request #220 from superimportantproject/bug/user-aliases - https://redmine.example.org/projects/superimportantproject/repository/revisions/5ceae86fa3573888f56a8b062f5694c66163b7fe\nRevision 776f3148 (superimportantproject-rails): Merge pull request #208 from superimportantproject/hotfix/leak-ticket-data-alias-fix - https://redmine.example.org/projects/superimportantproject/repository/revisions/776f3148c1099eacc5826cb8a68203deaced630f\nRevision 1e3f2a26 (superimportantproject-rails): Fix data leak between groups, user alias save bug - https://redmine.example.org/projects/superimportantproject/repository/revisions/1e3f2a26db7c3726b87d80c010ea41264fe84b11\nRevision 98954942 (superimportantproject-rails): Merge pull request #193 from superimportantproject/bug/192-schedule-mailer-test - https://redmine.example.org/projects/superimportantproject/repository/revisions/98954942113f5c549e8fb8187e14ffda4047e96a\nMore results: https://redmine.example.org/search?q=bug'],
      ]);
    });
  });

  it('searches for an issue with no results', async function () {
    nock('https://redmine.example.org')
      .get('/search.json?q=no%20results&limit=10')
      .replyWithFile(200, `${__dirname}/fixtures/search-empty.json`);

    const selfRoom = this.room;
    selfRoom.user.say('alice', '@hubot redmine search no results');

    await eventually(() => {
      assert.deepEqual(selfRoom.messages, [
        ['alice', '@hubot redmine search no results'],
        ['hubot', '@alice No search results for no results'],
      ]);
    });
  });

  it('ignores issue mention by default', async function () {
    const selfRoom = this.room;
    selfRoom.user.say('alice', 'What about RM100?');

    await delay(50);
    assert.deepEqual(selfRoom.messages, [
      ['alice', 'What about RM100?'],
    ]);
  });
});

describe('custom issue listener', () => {
  beforeEach(function () {
    process.env.HUBOT_LOG_LEVEL = 'error';
    process.env.HUBOT_REDMINE_BASE_URL = 'https://redmine.example.org';
    process.env.HUBOT_REDMINE_TOKEN = 'foobarbaz123';
    process.env.HUBOT_REDMINE_MENTION_REGEX = 'RM(\\d+)';
    nock.disableNetConnect();
    this.room = createRoom();
  });

  afterEach(function () {
    delete process.env.HUBOT_LOG_LEVEL;
    delete process.env.HUBOT_REDMINE_BASE_URL;
    delete process.env.HUBOT_REDMINE_TOKEN;
    delete process.env.HUBOT_REDMINE_MENTION_REGEX;
    nock.cleanAll();
    nock.enableNetConnect();
    this.room.destroy();
  });

  it('responds when issue mentioned', async function () {
    nock('https://redmine.example.org')
      .get('/issues/100.json')
      .replyWithFile(200, `${__dirname}/fixtures/issues-100.json`);

    const selfRoom = this.room;
    selfRoom.user.say('alice', 'What about RM100?');

    await eventually(() => {
      assert.deepEqual(selfRoom.messages, [
        ['alice', 'What about RM100?'],
        ['hubot', 'Defect #100 (Redmine): New Project - subproject list should not show archived projects (Closed) [Normal]'],
        ['hubot', 'https://redmine.example.org/issues/100'],
      ]);
    });
  });
});

describe('missing configuration', () => {
  beforeEach(function () {
    process.env.HUBOT_LOG_LEVEL = 'error';
    nock.disableNetConnect();
    this.room = createRoom();
  });

  afterEach(function () {
    delete process.env.HUBOT_LOG_LEVEL;
    nock.cleanAll();
    nock.enableNetConnect();
    this.room.destroy();
  });

  it('does not register listeners if not configured properly', function () {
    assert.equal(this.room.robot.responders.length, 0);
  });
});

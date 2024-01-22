// Description:
//   Interact with a Redmine instance.
//
// Dependencies:
//   None
//
// Commands:
//   hubot redmine show <issue-id> - Show the issue status
//   hubot redmine starting <issue-id> - Set the issue status, Defaults to "In Progress"
//   hubot redmine show (my|user's) issues - Show your issues or another user's issues
//   hubot redmine assign <issue-id> to <user-first-name> ["notes"]  - Assign the issue to the user (searches login or firstname)
//   hubot redmine update <issue-id> with "<note>"  - Adds a note to the issue
//   hubot redmine add <hours> hours to <issue-id> ["comments"]  - Adds hours to the issue with the optional comments
//   hubot redmine add issue to "<project>" [tracker <id>] with "<subject>"  - Add issue to specific project
//   hubot redmine link me <issue-id> - Returns a link to the redmine issue
//   hubot redmine set <issue-id> to <int>% ["comments"] - Updates an issue and sets the percent done
//   hubot redmine redmine search <query> - Search for a particular issue, wiki page, etc.
//

const Redmine = require('axios-redmine');

module.exports = (robot) => {
  // Ensure configuration variables are set
  let redmine;
  if (process.env.HUBOT_REDMINE_BASE_URL == null) {
    robot.logger.error('HUBOT_REDMINE_BASE_URL configuration variable missing.');
    return;
  }
  if (process.env.HUBOT_REDMINE_TOKEN == null) {
    robot.logger.error('HUBOT_REDMINE_TOKEN configuration variable missing.');
    return;
  }

  // Initialize Redmine connection
  try {
    redmine = new Redmine(
      process.env.HUBOT_REDMINE_BASE_URL,
      { apiKey: process.env.HUBOT_REDMINE_TOKEN },
    );
  } catch (error) {
    const err = error;
    robot.logger.error(err);
    return;
  }

  // simple ghetto fab date formatter this should definitely be replaced, but didn't want to
  // introduce dependencies this early
  //
  // dateStamp - any string that can initialize a date
  // fmt - format string that may use the following elements
  //       mm - month
  //       dd - day
  //       yyyy - full year
  //       hh - hours
  //       ii - minutes
  //       ss - seconds
  //       ap - am / pm
  //
  // returns the formatted date
  const formatDate = (dateStamp, fmt) => {
    if (fmt == null) {
      // eslint-disable-next-line no-param-reassign
      fmt = 'mm/dd/yyyy at hh:ii ap';
    }
    const dt = new Date(dateStamp);

    // split up the date
    const [m, d, y] = [dt.getMonth() + 1, dt.getDate(), dt.getFullYear()];
    let [h, i, s, ap] = [dt.getHours(), dt.getMinutes(), dt.getSeconds(), 'AM'];

    // leading 0s
    if (i < 10) { i = `0${i}`; }
    if (s < 10) { s = `0${s}`; }

    // adjust hours
    if (h > 12) {
      h -= 12;
      ap = 'PM';
    }

    // ghetto fab!
    return fmt
      .replace(/mm/, m)
      .replace(/dd/, d)
      .replace(/yyyy/, y)
      .replace(/hh/, h)
      .replace(/ii/, i)
      .replace(/ss/, s)
      .replace(/ap/, ap);
  };

  // tries to resolve ambiguous users by matching login or firstname
  // redmine's user search is pretty broad (using login/name/email/etc.) so
  // we're trying to just pull it in a bit and get a single user
  //
  // name - this should be the name you're trying to match
  // data - this is the array of users from redmine
  //
  // returns an array with a single user, or the original array if nothing matched
  const resolveUsers = (name, data) => {
    // eslint-disable-next-line no-param-reassign
    name = name.toLowerCase();
    // try matching login
    let found = data.filter((user) => user.login.toLowerCase() === name);
    if (found.length === 1) { return found; }

    // try first name
    found = data.filter((user) => user.firstname.toLowerCase() === name);
    if (found.length === 1) { return found; }

    // give up
    return data;
  };

  // Robot link me <issue>
  robot.respond(/(?:redmine|rm) link me (?:issue )?(?:#)?(\d+)/i, (msg) => {
    const id = msg.match[1];
    msg.reply(`${process.env.HUBOT_REDMINE_BASE_URL}/issues/${id}`);
  });

  // Robot set <issue> to <percent>% ["comments"]
  robot.respond(/(?:redmine|rm) set (?:issue )?(?:#)?(\d+) to (\d{1,3})%?(?: "?([^"]+)"?)?/i, (msg) => {
    let notes;
    const [id, percent, userComments] = msg.match.slice(1, 4);
    const donePercent = parseInt(percent, 10);

    if (userComments != null) {
      notes = `${msg.message.user.name}: ${userComments}`;
    } else {
      notes = `Ratio set by: ${msg.message.user.name}`;
    }

    const attributes = {
      notes,
      done_ratio: donePercent,
    };

    redmine.update_issue(id, attributes)
      .then((response) => {
        robot.logger.debug(response);
        msg.reply(`Set #${id} to ${donePercent}%`);
      }).catch((err) => {
        robot.logger.error(err);
        msg.reply(err);
      });
  });

  // Robot add <hours> hours to <issue_id> ["comments for the time tracking"]
  robot.respond(/(?:redmine|rm) add (\d{1,2}) hours? to (?:issue )?(?:#)?([+-]?([0-9]*[.])?[0-9]+)(?: "?([^"]+)"?)?/i, (msg) => {
    let comments;
    const [hours, id, userComments] = msg.match.slice(1, 4);

    if (userComments != null) {
      comments = `${msg.message.user.name}: ${userComments}`;
    } else {
      comments = `Time logged by: ${msg.message.user.name}`;
    }

    const attributes = {
      issue_id: id,
      hours,
      comments,
    };

    redmine.create_time_entry(attributes)
      .then((response) => {
        robot.logger.debug(response);
        msg.reply('Your time was logged');
      }).catch((err) => {
        robot.logger.error(err);
        msg.reply(err);
      });
  });

  // Robot show <my|user's> [redmine] issues
  robot.respond(/(?:redmine|rm) show @?(?:my|(\w+\s?'?s?)) (?:redmine )?issues/i, (msg) => {
    let userMode = true;
    let firstName = msg.message.user.name.split(/\s/)[0];
    if (msg.match[1] != null) {
      userMode = false;
      firstName = msg.match[1].replace(/'.+/, '').trim();
    }

    redmine.users({ name: firstName })
      .then((response) => {
        if (!(response.data.total_count > 0)) {
          throw new Error(`Couldn't find any users with the name "${firstName}"`);
        }
        return response.data.users;
      }).then((users) => resolveUsers(firstName, users)[0])
      .then((user) => {
        const params = {
          assigned_to_id: user.id,
          limit: 10,
          status_id: 'open',
          sort: 'priority:desc',
        };

        redmine.issues(params)
          .then((response) => {
            const output = [];

            if (userMode) {
              output.push(`You have ${response.data.total_count} issue(s).`);
            } else {
              output.push(`${user.firstname} has ${response.data.total_count} issue(s) and limiting to 10 issues here. :) `);
            }

            response.data.issues.forEach((issue) => {
              output.push(`\n[${issue.tracker.name} - ${issue.priority.name} - ${issue.status.name}] #${issue.id}: ${issue.subject}`);
            });

            msg.reply(output.join('\n'));
          }).catch((err) => {
            robot.logger.error(err);
            msg.reply("Couldn't get a list of issues for you!");
          });
      })
      .catch((err) => {
        robot.logger.error(err);
        msg.reply(err);
      });
  });

  // Robot update <issue> with "<note>"
  robot.respond(/(?:redmine|rm) update (?:issue )?(?:#)?(\d+)(?:\s*with\s*)?(?:[-:,])? (?:"?([^"]+)"?)/i, (msg) => {
    const [id, note] = msg.match.slice(1, 3);

    const attributes = { notes: `${msg.message.user.name}: ${note}` };

    redmine.update_issue(id, attributes)
      .then((response) => {
        robot.logger.debug(response);
        return msg.reply(`Done! Updated #${id} with "${note}"`);
      }).catch((err) => {
        robot.logger.error(err);
        return msg.reply(err);
      });
  });

  // Robot starting <issue> <status>
  robot.respond(/(?:redmine|rm) starting (?:issue )?(?:#)?(\d+) ?(?:([^*]+)?)?/i, (msg) => {
    let statusId;
    const [id, status] = msg.match.slice(1, 3);

    if (status != null) {
      if (status.match(/^New/i)) {
        statusId = 1;
      } else if (status.match(/Progress/i)) {
        statusId = 2;
      } else if (status.match(/Resolved/i)) {
        statusId = 3;
      } else if (status.match(/Feedback/i)) {
        statusId = 4;
      } else if (status.match(/Closed/i)) {
        statusId = 5;
      } else if (status.match(/Rejected/i)) {
        statusId = 6;
      } else {
        statusId = 2;
      }
    } else {
      statusId = 2;
    }

    const attributes = { status_id: `${statusId}` };

    redmine.update_issue(id, attributes)
      .then((response) => {
        robot.logger.debug(response);
        msg.reply(`Done! Issue id #${id} is now set to status '${status || 'In Progress'}'`);
      }).catch((err) => {
        robot.logger.error(err);
        msg.reply(err);
      });
  });

  // Robot add issue to "<project>" [tracker <id>] with "<subject>"
  robot.respond(/(?:redmine|rm) add (?:issue )?(?:\s*to\s*)?(?:"?([^" ]+)"? )(?:tracker\s)?(\d+)?(?:\s*with\s*)("?([^"]+)"?)/i, (msg) => {
    const [projectId, trackerId, subject] = msg.match.slice(1, 4);

    let attributes = {
      project_id: `${projectId}`,
      subject: `${subject}`,
    };

    if (trackerId != null) {
      attributes = {
        project_id: `${projectId}`,
        subject: `${subject}`,
        tracker_id: `${trackerId}`,
      };
    }

    redmine.create_issue(attributes)
      .then((response) => {
        robot.logger.debug(response);
        msg.reply(`Done! Added issue ${response.data.id} with "${subject}"`);
      }).catch((err) => {
        robot.logger.error(err);
        msg.reply(err);
      });
  });

  // Robot assign <issue> to <user> ["note to add with the assignment]
  robot.respond(/(?:redmine|rm) assign (?:issue )?(?:#)?(\d+) to (\w+)(?: "?([^"]+)"?)?/i, (msg) => {
    const [id, userName, note] = msg.match.slice(1, 4);
    redmine.users({ name: userName })
      .then((response) => {
        if (!(response.data.total_count > 0)) {
          throw new Error(`Couldn't find any users with the name "${userName}"`);
        }
        return response.data.users;
      }).then((users) => {
        // try to resolve the user using login/firstname -- take the first result (hacky)
        const user = resolveUsers(userName, users)[0];

        const attributes = { assigned_to_id: user.id };

        // allow an optional note with the re-assign
        if (note != null) { attributes.notes = `${msg.message.user.name}: ${note}`; }

        // get our issue
        redmine.update_issue(id, attributes)
          .then((response) => {
            robot.logger.debug(response);
            msg.reply(`Assigned #${id} to ${user.firstname}.`);
          });
      }).catch((err) => {
        robot.logger.error(err);
        msg.reply(err);
      });
  });

  // Robot redmine me <issue>
  robot.respond(/(?:redmine|rm)(?: show)?(?: me)? (?:issue )?(?:#)?(\d+)/i, (msg) => {
    const id = parseInt(msg.match[1], 10);

    const params = { include: 'journals' };

    redmine.get_issue_by_id(id, params)
      .then((response) => {
        robot.logger.debug(response);
        const {
          issue,
        } = response.data;
        const journals = [];
        journals.push(`\n[${issue.project.name} - ${issue.priority.name}] ${issue.tracker.name} #${issue.id} (${issue.status.name})`);
        let assignedToName = issue.assigned_to != null ? issue.assigned_to.name : undefined;
        assignedToName = assignedToName != null ? assignedToName : 'Nobody';
        journals.push(`Assigned: ${assignedToName} (opened by ${issue.author.name})`);
        if (issue.status.name.toLowerCase() !== 'new') {
          if (issue.spent_hours) {
            journals.push(`Progress: ${issue.done_ratio}% (${issue.spent_hours} hours)`);
          } else {
            journals.push(`Progress: ${issue.done_ratio}%`);
          }
        }
        journals.push(`Subject: ${issue.subject}`);
        journals.push(`\n${issue.description}`);

        // journals
        if (issue.journals != null) {
          journals.push(`\n${Array(10).join('-')}8<${Array(50).join('-')}\n`);
          issue.journals.forEach((journal) => {
            if ((journal.notes != null) && (journal.notes !== '')) {
              const date = formatDate(journal.created_on, 'mm/dd/yyyy (hh:ii ap)');
              journals.push(`${journal.user.name} on ${date}:`);
              journals.push(`    ${journal.notes}\n`);
            }
          });
        }

        return msg.reply(journals.join('\n'));
      });
  });

  // Robot redmine search <query>
  robot.respond(/(?:redmine|rm) search (.*)/i, (msg) => {
    const params = {
      q: msg.match[1],
      limit: process.env.HUBOT_REDMINE_SEARCH_LIMIT || 10,
    };

    // Search endpoint Not available in node-redmine@0.2.1
    robot.http(`${process.env.HUBOT_REDMINE_BASE_URL}/search.json`)
      .header('x-redmine-api-key', process.env.HUBOT_REDMINE_TOKEN)
      .query(params)
      .get()((err, _res, body) => {
        let data;
        if (err != null) {
          robot.logger.error(err);
          msg.reply(err);
          return;
        }

        try {
          data = JSON.parse(body);
        } catch (error1) {
          robot.logger.error(error1);
          msg.reply(error1);
          return;
        }

        if (data.total_count > 0) {
          const searchResults = [];
          data.results.forEach((result) => {
            searchResults.push(`${result.title} - ${result.url}`);
          });
          if (data.total_count > data.limit) {
            searchResults.push(`More results: ${process.env.HUBOT_REDMINE_BASE_URL}/search?q=${params.q}`);
          }
          msg.reply(searchResults.join('\n'));
          return;
        }
        msg.reply(`No search results for ${params.q}`);
      });
  });

  // Chime in on ticket mentions if enabled
  if (process.env.HUBOT_REDMINE_MENTION_REGEX != null) {
    robot.hear(RegExp(process.env.HUBOT_REDMINE_MENTION_REGEX), (msg) => {
      const matchIndex = process.env.HUBOT_REDMINE_MENTION_MATCH ? process.env.HUBOT_REDMINE_MENTION_MATCH : 1;
      const id = parseInt(msg.match[matchIndex], 10);
      // Ignore certain users, like Redmine plugins.
      const ignoredUsers = process.env.HUBOT_REDMINE_MENTION_IGNORE_USERS || '';
      if (Number.isNaN(id) || (id === 0) || ignoredUsers.split(',').includes(msg.message.user.name)) {
        return;
      }

      const params = {};

      redmine.get_issue_by_id(id, params)
        .then((response) => {
          robot.logger.debug(response);
          const {
            issue,
          } = response.data;
          const url = `${process.env.HUBOT_REDMINE_BASE_URL}/issues/${id}`;
          // Could be a template string for configurability?
          msg.send(`${issue.tracker.name} #${issue.id} (${issue.project.name}): ${issue.subject} (${issue.status.name}) [${issue.priority.name}]`);
          msg.send(`${url}`);
        }).catch((err) => {
          robot.logger.error(err);
          msg.reply(err);
        });
    });
  }
};

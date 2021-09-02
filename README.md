# Hubot Redmine

[![npm version](https://badge.fury.io/js/hubot-redmine.svg)](https://badge.fury.io/js/hubot-redmine) [![Node CI](https://github.com/robhurring/hubot-redmine/actions/workflows/nodejs.yml/badge.svg)](https://github.com/robhurring/hubot-redmine/actions/workflows/nodejs.yml)

Light mapping of the Redmine REST API that allows Hubot access to some basic Redmine tasks. Once you have a Redmine user (preferably one with enough access to modify tickets), add the following to your Heroku/etc. config:

    heroku config:add HUBOT_REDMINE_BASE_URL="http://redmine.your-server.com"
    heroku config:add HUBOT_REDMINE_TOKEN="your api token here"

## Installation

In hubot project repo, run:

`npm install hubot-redmine --save`

Then add **hubot-redmine** to your `external-scripts.json`:

```json
[
  "hubot-redmine"
]
```

## Configuration

| Environment Variable                 | Required? | Description                               |
| ------------------------------------ | :-------: | ----------------------------------------- |
| `HUBOT_REDMINE_BASE_URL`             | Yes       | URL to your Redmine install               |
| `HUBOT_REDMINE_TOKEN`                | Yes       | API key for your selected user            |
| `HUBOT_REDMINE_MENTION_REGEX`        | No        | Listen for this pattern and link to Redmine tickets when heard (default `/RM#(\d+)/`) |
| `HUBOT_REDMINE_MENTION_MATCH`        | No        | Index of matched capture from HUBOT_REDMINE_MENTION_REGEX (default  `1`) |
| `HUBOT_REDMINE_MENTION_IGNORE_USERS` | No        | Comma-separated list of users to ignore   |
| `HUBOT_REDMINE_SEARCH_LIMIT`         | No        | Maximum search results to show for "redmine search", default is `10` |

## Showing issue details

* @Hubot redmine show me [issue id]
* @Hubot redmine me [issue id]

## Showing my issue (or another user's)

* @Hubot redmine show my issues
* @Hubot redmine show [user]'s issues
** [user] will attempt to match on redmine firstname or login

## Re-Assigning tickets

* @Hubot redmine assign [issue id] to [user]

## Leaving notes on tickets

* @Hubot redmine update [issue id] with "[comments]"

## Create tickets

* @Hubot redmine add issue to "[project]" [traker id] with "[subject]"
** [tracker id] is optional and represent the number matching literal value Bug/Feature/...

## Get a link to an issue

* @Hubot redmine link me [issue id]

## Set the percent done of an issue

* @Hubot redmine set [issue id] to 100% "[comments]"
* @Hubot redmine add [hours] hours to [issue id] "[comments]"

## Search Redmine

The default results limit is 10, configurable via `HUBOT_REDMINE_SEARCH_LIMIT`.

* @Hubot redmine search <query>

[[ This is now being maintained in my [hubot-scripts](https://github.com/robhurring/hubot-scripts/blob/master/src/scripts/redmine.coffee) fork, and was merged into the hubot-scripts core. I still love pull requests though :) ]]

# Hubot Redmine

Light mapping of the Redmine REST API that allows hubot access to some basic redmine tasks. Once you have a redmine
user (preferably one with enough access to modify tickets), add the following to your heroku/etc. config:

    heroku config:add HUBOT_REDMINE_BASE_URL="http://redmine.your-server.com"
    heroku config:add HUBOT_REDMINE_TOKEN="your api token here"
  
![screenshot](https://github.com/robhurring/hubot-redmine/blob/master/ss.png?raw=true)

## Showing ticket details

* Hubot show me [ticket]
* Hubot redmine me [ticket]

## Showing my tickets (or another user's)

* Hubot show my tickets
* Hubot show [user]'s tickets
** [user] will attempt to match on redmine firstname or login

## Re-Assigning tickets

* Hubot assign [ticket] to [user]

## Leaving notes on tickets

* Hubot update [ticket] with "[note]"

## More coming!
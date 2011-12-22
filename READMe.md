[[ Temporary storage here while I work on it ]]

# Hubot Redmine

Light mapping of the Redmine REST API that allows hubot access to some basic redmine tasks. Once you have a redmine
user (preferably one with enough access to modify tickets), add the following to your heroku/etc. config:

    heroku config:add HUBOT_REDMINE_BASE_URL="http://redmine.your-server.com"
    heroku config:add HUBOT_REDMINE_TOKEN="your api token here"
  
![screenshot](https://github.com/robhurring/hubot-redmine/blob/master/ss.png?raw=true)

## Showing ticket details

* Hubot show me [ticket]
* Hubot redmine me [ticket]

## Re-Assigning tickets

* Hubot assign [ticket] to [user]

## Leaving notes on tickets

* Hubot update [ticket] with "[note]"

## More coming!
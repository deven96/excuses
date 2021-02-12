# Excuses

Send an excuse to your "I will be away" Channel on slack after x seconds away from your computer

## Setup

```bash
#Configure the following env variables for slack
#- APP_SLACK_WEBHOOK
#- APP_SLACK_CHANNEL (optional)
#- APP_SLACK_USERNAME (optional)
#- APP_SLACK_ICON_EMOJI (optional)

# Make sure to add chat:write access to your app to enablethe application post as your user and not as Bot
# Read https://api.slack.com/scopes
```

Make sure excuses is executable
```bash
chmod +x ./excuses.sh
```

Use nohup to run in background

```bash
# I considered using crontab but cronjobs have no access to GUI sessions (Quarz dictionary on MacOS) used to tell 
# if a system is locked or not, 
# enter the following to run excuses
`./excuses.sh &>/tmp/excuses.log`
```

This sets up a [slack shell script](https://gist.github.com/andkirby/67a774513215d7ba06384186dd441d9e) that helps in sending messages to channels 


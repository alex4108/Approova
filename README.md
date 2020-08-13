# Approova Discord Bot

[![GitHub issues](https://img.shields.io/github/issues/alex4108/Approova)](https://github.com/alex4108/Approova/issues)
[![GitHub forks](https://img.shields.io/github/forks/alex4108/Approova)](https://github.com/alex4108/Approova/network)
[![GitHub stars](https://img.shields.io/github/stars/alex4108/Approova)](https://github.com/alex4108/Approova/stargazers)
[![GitHub license](https://img.shields.io/github/license/alex4108/Approova)](https://github.com/alex4108/Approova/blob/master/LICENSE)
![GitHub All Releases](https://img.shields.io/github/downloads/alex4108/Approova/total)
![GitHub contributors](https://img.shields.io/github/contributors/alex4108/Approova)

## Purpose

Let existing users of a discord guild approve new joins

Did I save you some time?  [Buy me a :coffee::smile:](https://venmo.com/alex-schittko)

## Basic flow

1. User joins discord guild
1. Approvals Team will be messaged via Approvals Channel
1. A member of the approvals team will confirm their approval
1. The user who joined will be given the public role

## Configure the bot

_Bot will listen with prefix * and will only listen to the Guild owner!__

1. Join the bot to your server [LIVE](https://discord.com/api/oauth2/authorize?client_id=743249218491121695&permissions=268635200&scope=bot) [DEV](https://discord.com/api/oauth2/authorize?client_id=743260532571635804&permissions=268635200&scope=bot)
1. `*setApproverChannel <name of channel>` to set the moderator's room
1. `*setApproverRole <name of role>` to set the role to assign on approval
1. `*setPublicChannel <name of channel>` to set the public room for announcements
1. `*setPublicRole Channel <name of channel>` to set the public room for announcements
1. Move `Approova` role to top of roles list in Discord Guild Settings

## Starting the server

The .env file consists of one line, DISCORD_TOKEN=yourDiscordBotTokenHere

#### Development

* `virtualenv env && source env/bin/activate && pip install -r requirements.txt` for first time
* `source env/bin/activate` for continuing

* Then start Development

#### Production

```
docker build -t approva . 
docker run -d approva 
```

OR, force a volume mount to your local .env file inside the container, and persist the sqlite.db

```
docker build -t approva . 
docker run -d -v /path/to/your/.env:/app/.env -v /path/to/your/sqlite.db:/app/sqlite.db approva 
```

# Contributing

Contributions are what make the open source community such an amazing place to be learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

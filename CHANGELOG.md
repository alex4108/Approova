# Release RELEASE_VERSION

## Breaking Changes

* None!

## Bugs

* Modified SQL syntax to use "delete and insert" strategy versus attempt in-place updates.  This will help configuration changes take effect more frequently.

## Improvements

* Bump to discord.py 1.6.0

* Modified Discord configuration to accept channels with just a name, or a #name (links)

* Modified bot's chatter to use #links instead of plain channel names

* Modified bot's logging to be less noisy

* Modified bot to inform discord users of approval rejections


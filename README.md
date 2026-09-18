![rss-to-whapi-illustration](https://github.com/user-attachments/assets/bd1debef-a2f8-461d-8853-7c520eb70f55)

## Background

I’m always keen to experiment with new ways to subscribe to my blog. Obviously RSS is the best and everybody who can use it should. [But some people, for their own reasons, prefer to learn about updates to their favourite sites via other mechanisms...](https://danq.me/2025/11/23/rss-to-whatsapp/)

## Prerequisites

You will need:

1. A [Whapi.cloud](https://whapi.cloud/) account - when you set up an account you’ll get a free trial; when it ends you need to find the link to say that you want to carry on with the free tier (or upgrade to the paid tier if you expect to send more messages than the free tier’s limit)
2. A WhatsApp channel to which you want to push your RSS feed: I’d recommend that you make a newsletter (from the Updates tab in WhatsApp, press the kekab menu then Create Channel) rather than a traditional group

## Instructions

1. Fork this repository into your own GitHub account.
2. In Settings > Secrets and Variables > Actions, add two new Repository Secrets:
    - `WHATSAPP_API_TOKEN`: set to the token on your Whapi dashboard
    - `WHATSAPP_CHANNEL`: set to your newsletter ID (will look like 123456789012345678@newsletter) or group ID (will look like 123456789012345678@g.us)
3. Make a `feeds.json` file (a feeds.json.example is provided as a guide) containing the URLs of the RSS feeds you’d like to subscribe to.
4. Do a test run: from the Actions tab select the “Process feeds” action and click “Run workflow”. If it finishes successfully (and you get the WhatsApp message), you’re done! If it fails, click on the failed action and drill-in to the failed task to see the error message and correct accordingly.

By default, the processor will run on-demand and every 30 minutes, but you can modify that in `.github/workflows/process-feeds.yml`.

It’s configured to send the single oldest un-sent item in any of the RSS feeds it’s subscribed to, on each run (it tracks which ones it’s sent already by their guids, in a `"seen": [...]` array in `feeds.json`):
sending a single link per run ensures that WhatsApp’s link previews work as expected. At that rate, you could theoretically run it once every 10 minutes and never hit the 150-messages-per-day limit of Whapi’s free tier),
but you’ll want to work out your own optimal rate based on the anticipated update frequency of your feeds and the number of RSS-to-WhatsApp channels you’re running.

### Getting your channel ID

You can get this from the Newsletters or Groups section of Whapi by executing a test GET /newsletters or GET /groups request

Prefer the command-line? So long as you’ve got `curl` and `jq` then you can get a list of your newsletters (or groups) and their IDs with:

```
curl -H 'Authorization: Bearer YOUR_API_TOKEN' -H 'accept: application/json' https://gate.whapi.cloud/newsletters?count=100 | jq '.newsletters[] | { id: .id, name: .name }'
```

Or for groups (not recommended):

```
curl -H 'Authorization: Bearer YOUR_API_TOKEN' -H 'accept: application/json' https://gate.whapi.cloud/groups?count=100 | jq '.groups[] | { id: .id, name: .name }'
```

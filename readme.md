# Telegram PowerShell AD Locked User Bot
This guide will explain how to create a telegram bot and retrieve the code, and how to setup a scheduled task that will run this script on an active directory user lockout. There is a module for Zendesk to escalate locked users to a ticket. Feel free to edit that to your own ticketing system.

For ease of use I have the variables directly in the script. For a more secure approach please use a gmsa "Group Managed Service Account" and a PowerShell vault for your variables.

## Telegram Bot Setup and Group ID Retrieval
This guide will walk you through the steps to create a Telegram bot token and retrieve the group ID.

### Prerequisites
- A Telegram account
- Telegram app installed on your device

### Step 1: Creating a Telegram Bot Token
Open Telegram App: Launch the Telegram app on your device.

Start a Chat with BotFather: Search for BotFather in the search bar and start a chat with it. BotFather is the official bot to create and manage Telegram bots.

Create a New Bot:

Type /newbot and send the message.
Follow the instructions to set a name and username for your bot. The username must end in bot (e.g., example_bot).
Get the Bot Token:

Once the bot is created, BotFather will provide you with a token. This token is important and will be used to authenticate your bot with the Telegram API. Keep this token secure.
### Step 2: Adding Your Bot to a Group
Create a New Group:

In Telegram, create a new group or use an existing one.
Add your bot to the group. You can do this by searching for the bot's username and adding it to the group.
Promote Your Bot to Admin (Optional but Recommended):

In the group settings, promote your bot to admin. This gives your bot necessary permissions to interact with group messages.
### Step 3: Retrieving the Group ID
Send a Message in the Group: Send any message in the group where your bot is added.

Retrieve Group ID via Bot API:

Use the following URL to get updates from your bot (replace YOUR_BOT_TOKEN with the token you got from BotFather):
```bash
https://api.telegram.org/botYOUR_BOT_TOKEN/getUpdates
```
Open this URL in your web browser. You should see a JSON response with the latest updates.
Extract the Group ID:

Look for the "chat" object in the JSON response. Inside this object, you will find the "id" field. This is your group ID.

### Example JSON Response
Here is a simplified example of what the JSON response might look like:

```json
{
  "ok": true,
  "result": [
    {
      "update_id": 123456789,
      "message": {
        "message_id": 1,
        "from": {
          "id": 987654321,
          "is_bot": false,
          "first_name": "John",
          "username": "john_doe"
        },
        "chat": {
          "id": -1234567890,
          "title": "Example Group",
          "type": "group"
        },
        "date": 1594676800,
        "text": "Hello, World!"
      }
    }
  ]
}
```
In this example, the "id" field inside the "chat" object (-1234567890) is the group ID.

### Conclusion
You have successfully created a Telegram bot token and retrieved the group ID. You can now use these in your bot development to interact with your Telegram group.



## Creating a scheduled task to run the Locked User Bot triggered by an active directory lockout
This guide will walk you through the steps to create a scheduled task that runs a PowerShell script triggered by an Active Directory (AD) account lockout.

### Prerequisites
- Administrative privileges on the server or workstation where the task will be created
- Basic knowledge of PowerShell scripting
- PowerShell 7 https://github.com/PowerShell/PowerShell/releases
- Access to Active Directory

### Step 1: Prepare the PowerShell Script
Copy the locked_user_bot.ps1 to the location you want to execute your scripts from. We are going to use "c:\scripts\locked_user". Make sure to edit the variables within the script. Zendesk is optional and you could swap this with your ticketing system as long as it has an API.
```powershell
# Variables
$botToken = ""
$chatID = ""
$zendeskDomain = ""
$zendeskEmail = ""
$zendeskToken = ""
```

### Step 2: Import Scheduled Task
1. Open Task Scheduler
Open Task Scheduler by searching for it in the Start menu or running taskschd.msc.
2. Import Task
In the Task Scheduler, click on Action > Import Task.
3. Import the locked_user_bot.xml

### Conclusion
You have successfully created a scheduled task to run the PowerShell script triggered by an active directory account lockout. Go ahead and lock a user out and test unlocking.



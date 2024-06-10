<#	
	.NOTES
      Filename:      locked_user_bot.ps1
      Prerequisites: PowerShell 7+
	.DESCRIPTION
	  Alert techs on users locked out and allow them to unlock remotely.
#>
# Passed parameters from event log 4740
param (
  $TargetUserName,
  $TargetDomainName
)

# Variables
$botToken = ""
$chatID = ""
$zendeskDomain = ""
$zendeskEmail = ""
$zendeskToken = ""

# Grab other AD user vairables
$lockedUser = Get-ADUser -Identity $TargetUserName -Properties Name, lockedout, lockoutTime  | Select-Object Name, lockedout, @{ Name = "LockoutTime"; Expression = { ([datetime]::FromFileTime($_.lockoutTime).ToLocalTime()) } }
$name = $lockedUser.Name
$lockoutTime = ($lockedUser.LockoutTime.ToString("hh:mm:ss tt"))

# Functions
function Send-TelegramMsg {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            HelpMessage = '#########:xxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxx')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$BotToken,

        [Parameter(Mandatory = $true,
            HelpMessage = '-#########')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$ChatID,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Text of the message to be sent')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false,
            HelpMessage = 'HTML vs Markdown for message formatting')]
        [ValidateSet('Markdown', 'MarkdownV2', 'HTML')]
        [string]$ParseMode = 'HTML', #set to HTML by default

        [Parameter(Mandatory = $false,
            HelpMessage = 'Custom or inline keyboard object')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [psobject]$Keyboard,

        [Parameter(Mandatory = $false,
            HelpMessage = 'Disables link previews')]
        [switch]$DisablePreview, #set to false by default

        [Parameter(Mandatory = $false,
            HelpMessage = 'Send the message silently')]
        [switch]$DisableNotification
    )
    #------------------------------------------------------------------------
    $results = $true
    #------------------------------------------------------------------------
    $PL = @{
        chat_id                  = $ChatID
        text                     = $Message
        parse_mode               = $ParseMode
        disable_web_page_preview = $DisablePreview.IsPresent
        disable_notification     = $DisableNotification.IsPresent
    }
    if ($Keyboard) { $PL.Add('reply_markup', $Keyboard) }
    #------------------------------------------------------------------------
    $invokeRestMethod = @{
        Uri         = ('https://api.telegram.org/bot{0}/sendMessage' -f $BotToken)
        Body        = ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -Compress -InputObject $PL -Depth 8)))
        ErrorAction = 'Stop'
        ContentType = 'application/json'
        Method      = 'Post'
    }
    #------------------------------------------------------------------------
    try {
        $Response = Invoke-RestMethod  @invokeRestMethod
        if ($Response.ok) {
            return $Response.result.message_id
        } else {
            Write-Host "Telegram API returned an error: $($Response.description)"
            return $null
        }
    } catch {
        Write-Host "Exception caught: $_"
        return $null
    }    
    #------------------------------------------------------------------------
}#function Send-TelegramMsg
function Edit-TelegramMsg {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            HelpMessage = '#########:xxxxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxx')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$botToken,

        [Parameter(Mandatory = $true,
            HelpMessage = '-#########')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$chatID,

        [Parameter(Mandatory = $true,
            HelpMessage = '#######')]          
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$MessageID,

        [Parameter(Mandatory = $true,
            HelpMessage = 'Text of the message to be sent')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory = $false,
            HelpMessage = 'HTML vs Markdown for message formatting')]
        [ValidateSet('Markdown', 'MarkdownV2', 'HTML')]
        [string]$ParseMode = 'HTML', #set to HTML by default

        [Parameter(Mandatory = $false,
            HelpMessage = 'Custom or inline keyboard object')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [psobject]$Keyboard,

        [Parameter(Mandatory = $false,
            HelpMessage = 'Disables link previews')]
        [switch]$DisablePreview #set to false by default        
    )
    #------------------------------------------------------------------------
    $results = $true
    #------------------------------------------------------------------------
    $PL = @{
        chat_id                  = $chatID
        message_id               = $MessageID
        text                     = $Message
        parse_mode               = $ParseMode
        disable_web_page_preview = $DisablePreview.IsPresent        
    }
    if ($Keyboard) { $PL.Add('reply_markup', $Keyboard) }
    #------------------------------------------------------------------------
    $invokeRestMethod = @{
        Uri         = ('https://api.telegram.org/bot{0}/editMessageText' -f $botToken)
        Body        = ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -Compress -InputObject $PL -Depth 8)))
        ErrorAction = 'Stop'
        ContentType = 'application/json'
        Method      = 'Post'
    }
    #------------------------------------------------------------------------
    try {
        Write-Verbose -Message 'Editing Telegram message...'
        $results = Invoke-RestMethod @invokeRestMethod
    }#try_messageSend
    catch {
        Write-Warning -Message 'An error was encountered editing the Telegram message:'
        Write-Error $_
        $results = $false
    }#catch_messageSend
    return $results
    #------------------------------------------------------------------------
}#function Edit-TelegramMsg
function Get-TelegramUpdates {
    # API Request
    $Uri = "https://api.telegram.org/bot$($botToken)/getUpdates"
    $BotUpdates = Invoke-WebRequest -Uri $Uri
    $BotUpdatesJson = $BotUpdates.Content | ConvertFrom-Json
    return $BotUpdatesJson.result
}#function Get-TelegramUpdates
function Create-Zendesk_Ticket {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true,
            HelpMessage = 'Title of Zendesk Ticket')]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$Subject,
          
        [Parameter(Mandatory = $true,
            HelpMessage = 'Main Body, of ticket to be created within Zendesk')]          
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$Comment,        

        [Parameter(Mandatory = $false,
            HelpMessage = 'Set Zendesk Ticket Comment Public or Private')]        
        [string]$IsPublic,
        
        [Parameter(Mandatory = $false,
            HelpMessage = 'Zendesk Group to be assigned to ticket')]          
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [string]$GroupID,

        [Parameter(Mandatory = $false,
            HelpMessage = 'Set Zendesk Ticket Type problem, incident, question, or task')]          
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('problem', 'incident', 'question', 'task')]
        [string]$Type,

        [Parameter(Mandatory = $false,
            HelpMessage = 'Set Zendesk Ticket Priority urgent, high, normal, or low')]          
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('urgent', 'high', 'normal', 'low')]
        [string]$Priority,
        
        [Parameter(Mandatory = $false,
            HelpMessage = 'Set Zendesk Ticket Status new, open, pending, hold, solved, or closed')]          
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('new', 'open', 'pending', 'hold', 'solved', 'closed')]
        [string]$Status,  
        
        [Parameter(Mandatory = $false,
            HelpMessage = 'Set your tags for Zendesk')]          
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]        
        [array]$Tags
    )
    #------------------------------------------------------------------------
    $results = $true
    #------------------------------------------------------------------------
    $header = @{        
        Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($zendeskEmail):$($zendeskToken)"));
    }
    #------------------------------------------------------------------------
    $PL = @{
        ticket = @{
            subject = $Subject
            comment = @{ 
                body = $Comment
            }            
        }
    }

    if ($GoupID) { $PL.ticket.group_id = $GroupID }
    if ($Type) { $PL.ticket.type = $Type }
    if ($Priority) { $PL.ticket.priority = $Priority }
    if ($Status) { $PL.ticket.status = $Status }   
    if ($Tags) { $PL.ticket.tags = $Tags }    
    if ($DueDate) { $PL.ticket.due_at = $DueDate }
    #------------------------------------------------------------------------
    $invokeRestMethod = @{
        Uri         = "https://$zendeskDomain.zendesk.com/api/v2/tickets.json"
        Header      = $header
        Body        = ([System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -Compress -InputObject $PL -Depth 8)))
        ErrorAction = 'Stop'
        ContentType = 'application/json'
        Method      = 'Post'
    }
    #------------------------------------------------------------------------
    try {
        Write-Verbose -Message 'Creating Zendesk Ticket...'
        $results = Invoke-RestMethod @invokeRestMethod
    }#try_messageSend
    catch {
        Write-Warning -Message 'An error was encountered creating the Zendesk Ticket:'
        Write-Error $_
        $results = $false
    }#catch_messageSend
    return $results
    #------------------------------------------------------------------------
}#function Create-Zendesk_Ticket

#Initial Telegram Lockout Message
$Row1 = @(
    @{
        text = "🔓 Unlock";
        callback_data = "Unlock $name $lockoutTime"
    },
    @{
        text = "🚨 Create Ticket";
        callback_data = "Ticket $name $lockoutTime"
    }
)
$Row2 = @(
)
$Keyboard = @{
    inline_keyboard = @(
        $Row1, $Row2
    )
}
$Message = @{
    botToken = $botToken
    chatID   = $chatID
    Message  = "<b>Lockout Notification:</b>`nUser: <i>$name</i>`nLockout Time: $lockoutTime `nSource Machine: $TargetDomainName"
    Keyboard = $Keyboard
}
$messageId = Send-TelegramMsg @Message

# Keywords 
$userUnlock = "Unlock $name $lockoutTime"
$userTicket = "Ticket $name $lockoutTime"
    
# Define the timeout duration in minutes
$timeoutMinutes = 50
$startTime = Get-Date

# Loop flag to identify if the loop ended due to a condition
$conditionMet = $false

# Main loop to continuously check for updates allotted time in minutes
while ((Get-Date) -lt $startTime.AddMinutes($timeoutMinutes) -and -not $conditionMet) {
    $BotUpdateArray = Get-TelegramUpdates

    foreach ($update in $BotUpdateArray) {
        if ($update.callback_query) {
            $callbackQuery = $update.callback_query
            # Check for unlocking user
            if ($callbackQuery.message.chat.id -eq $chatID -and $callbackQuery.message.message_id -eq $messageId -and $callbackQuery.data -eq $userUnlock) {                
                # Query user who selected the action
                $actionUserFirstName = $callbackQuery.from.first_name
                $actionUserLastName = $callbackQuery.from.last_name                
                
                # Unlock User
                Unlock-ADAccount $TargetUserName                
                Write-Host "$ActionUserFirstName $ActionUserLastName unlocked $name who was locked out at $lockoutTime"
                
                # Edit Telegram Message
                $unlockMessage = @{
                    botToken  = $botToken          
                    chatID    = $chatID
                    MessageID = $messageID
                    Message   = "$actionUserFirstName $actionUserLastName unlocked $name"            
                }
                Edit-TelegramMsg @unlockMessage
                
                $conditionMet = $true # Stop main loop
                break # Stop the inner loop
            }
            # Check for creating a ticket
            if ($callbackQuery.message.chat.id -eq $chatID -and $callbackQuery.message.message_id -eq $messageId -and $callbackQuery.data -eq $userTicket) {                
                # Query user who selected the action
                $actionUserFirstName = $callbackQuery.from.first_name
                $actionUserLastName = $callbackQuery.from.last_name
                                
                # Create Zendesk Ticket
                $ticket = @{
                    Subject  = "Locked User - $name"
                    Comment  = "$actionUserFirstName $actionUserLastName wants to investigate $name further to see why they are continually getting locked out."
                    Type     = 'task' 
                    Priority = 'high'
                    Status   = 'new'
                    Tags     = 'internal, lockout'      
                }
                Create-Zendesk_Ticket @ticket
                                
                #Update Telegram Message         
                $ticketMessage = @{
                    botToken  = $botToken          
                    chatID    = $chatID
                    MessageID = $messageID
                    Message   = "$actionUserFirstName $actionUserLastName created an escalated ticket for $name"            
                }
                Edit-TelegramMsg @ticketMessage

                $conditionMet = $true # Stop main loop
                break # Stop the inner loop
            }
        }
    }

    # Wait for 3 seconds before the next update check
    Start-Sleep -Seconds 3
}

# After the loop, check why it was stopped
if (-not $conditionMet) {
    Write-Host Timeout has been reached, no action was taken on $name.       
    #Update Telegram Message      
    $timeoutMessage = @{
        botToken  = $botToken          
        chatID    = $chatID
        MessageID = $messageID
        Message   = "<b>Lockout Notification:</b>`nThe 50 minute timeout has been reached, no action was taken on $name that was locked out at $lockoutTime."            
    }
    Edit-TelegramMsg @timeoutMessage 
} else {
    Write-Host "Action taken based on the condition met inside the loop."
}
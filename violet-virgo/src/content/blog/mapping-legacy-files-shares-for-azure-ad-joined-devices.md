---
title: "Mapping legacy files shares for Azure AD joined devices"
pubDate: "2019-04-07"
categories:
  - "intune"
  - "it"
tags:
  - "drive-mapping"
  - "intune"
  - "microsoft"
  - "powershell"
  - "script"
  - "windows"
  - "windows-10"
heroImage: "/blog-intune-tech.png"
description: "The blog post discusses the challenge of mapping legacy file shares for devices joined to Microsoft Entra ID. As organizations transition to modern IT environments using Azure AD and Microsoft Intune, they often face difficulties in providing access to on-premises file shares. The author describes a solution involving PowerShell scripts to map network drives at user sign-in, addressing the limitations of traditional methods like Group Policy Preferences and login scripts. This approach supports both dedicated and shared devices, ensuring seamless access to legacy file shares while moving towards a modern desktop infrastructur"
---

More and more of my customers are moving their devices from a traditional IT model to a Modern Desktop build directly in Azure AD, managing devices via Microsoft Intune rather than Group Policy or System Center Configuration Manager. The move to this modern approach of delivering IT services usually sits alongside of moving the organisation's unstructured file data to OneDrive and SharePoint online which is the logical place to store this data instead of sat on a file server in an office or datacentre.

What if, however, that you still have a large volume of data that remains on your on premises file servers. Users will still require access to these shares but there is no native way of connecting to file shares within the Intune console. This is the challenge I have had for a customer in recent weeks and have developed a couple of PowerShell scripts that can be run to map drives when a user logs in and supports both dedicated and shared devices.

## The Challenge

Looking back at a legacy IT approach, drive mappings were done through either Group Policy Preferences but also through login scripts such as batch or KIX. Both processes follow a similar method:

1. User signs into a device
2. GPP or login script runs containing list of mapped drives aligned to security groups of users who should have access
3. If the user signing into the device is in the relevant groups the drive letter is mapped to the shared location

This method has worked for years and IT admins maintain one or the other process to give users access to corporate data. If we now look forward to the modern managed IT environment, there are a few issues when working with the legacy file servers:

- There is no native construct in Intune that maps UNC file paths for users
- Whilst you can run a PowerShell script that could run a [New-PSDrive](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/new-psdrive?view=powershell-6) cmdlet this will only execute once on the device and never again.

You may think that the second piece isn't an issue, simply create a couple of scripts to map the network drives to the file shares and they will run once and remain mapped. What if the devices are shared and multiple users need to sign into the computer or if you need to amend the drive mappings? We needed a solution that could map drives at user sign in and be easy to change as the organisation moves away from file servers.

## The Solution

As with most things, I started looking at what was on the Internet and quickly came across these blogs from [Nicola Suter](https://tech.nicolonsky.ch/intune-execute-powershell-script-on-each-user-logon/) and [Jos Lieben](http://www.lieben.nu/liebensraum/2018/06/mapping-legacy-server-shares-in-your-windows-10-mdm-intune-pilot/) but neither really did what I needed for my customer (they have >100 different network drives). I set about looking for scripts that would deliver what I needed for the customer.

My requirements for the new drive mapping script were as follows:

- Work natively with Azure AD joined devices
- support users on dedicated or shared workstations
- process the drive mappings sequentially as a traditional GPP or Login script would execute

Let's start with the actual drive mapping script itself

### Drive mapping script

For the drive mapping script to work, it needs to run silently and also enumerate the groups that the user has access to. Sounds easy, but PowerShell and AzureAD doesn't natively have a way of matching these. I settled on making use of Microsoft's Graph API [listMemberOf](https://docs.microsoft.com/en-us/graph/api/user-list-memberof?view=graph-rest-1.0) function as this can be called to pull the groups that a user is a member of into a variable that can work with the drive mapping. The function requires a minimum permission of Directory.ReadAll which needed to be granted through an App Registration in Azure AD. Step forward my next web help in the form of [Lee Ford's](https://www.lee-ford.co.uk/getting-started-with-microsoft-graph-with-powershell/) blog on using Graph API with PowerShell

#### Configure Azure AD

First sign into Azure Portal and navigate to Azure AD and Application Registrations (Preview) to create a new App Registration. Give the app a name

<figure>

![](https://i1.wp.com/matthewjwhite.co.uk/wp-content/uploads/2019/04/1-new-registration.jpg?fit=640%2C526&ssl=1)

<figcaption>

Create new App Registration

</figcaption>

</figure>

When its created you will be shown the new app details. make sure that you note down the **Directory ID** and the **Application (client) ID** as you will need these in the script.

<figure>

![](https://i2.wp.com/matthewjwhite.co.uk/wp-content/uploads/2019/04/2-note-app-and-directory-IDs.jpg?fit=640%2C121&ssl=1)

<figcaption>

App and Directory ID values will be used in the script

</figcaption>

</figure>

As well as these ID values, you also need a Redirect URI that is referenced in the script, click on **Add a Redirect URI** and choose the item in the screenshot below then click **Save**.

![](https://i2.wp.com/matthewjwhite.co.uk/wp-content/uploads/2019/04/3-setredirectURI.jpg?fit=640%2C231&ssl=1)

Now that the app is registered, we need to add permissions to read data from Graph API. Click on the **API Permissions** heading to grant the required **Directory.ReadAll** delegated permission.

<figure>

![](https://i1.wp.com/matthewjwhite.co.uk/wp-content/uploads/2019/04/4-add-permissinos.jpg?fit=640%2C396&ssl=1)

<figcaption>

Add the Directory.ReadAll permission to the App Registration

</figcaption>

</figure>

By default the user's making a connection to the API will be required to consent to the permissions change. To make this seamless, we can use our administrative account to grant this consent on behalf of all organisation users.

<figure>

![](https://i2.wp.com/matthewjwhite.co.uk/wp-content/uploads/2019/04/5-grantconsent.jpg?fit=640%2C301&ssl=1)

<figcaption>

Grant Admin consent

</figcaption>

</figure>

This is the setup of the Azure AD Application that will be used to access the Graph API, we can now focus on the PowerShell script that will map the drives.

#### The Drive Mapping Script

The Drive mapping script is made up of several parts:

- Configuration section where you setup the Application Registration and drive mappings that will be run for each user
- Connection to the Graph API
- Enumeration of group membership for the user
- Iterating through all drive maps and mapping those that the user is a member of.

I will share the script in full further down this post but have included the key snippets in each location.

First we define the variables for the app registration we created earlier.

```powershell
$clientId = "73b7bec7-738#-####-####-############" #This is the Client ID for your Application Registration in Azure AD
$tenantId = "3b7b2097-f13#-####-####-############" # This is the Tenant ID of your Azure AD Directory
$redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient" # This is the Return URL for your Application Registration in Azure AD
$dnsDomainName = "skunklab.co.uk" #This is the internal name of your AD Forest/
```

Once these are in place we setup our array of drive mappings. In this section there are four attributes that can be defined:

- includeSecurityGroup - this is the group of users who should have the drive mapped
- excludeSecurityGroup - this is a group of users who shouldnt have the drive mapped (this is optional)
- driveLetter - this is the alphabetical letter that will be used as part of the drive mapping
- UNCPath - this is the reference to the file share that should be mapped to the drive letter.

The code in the script looks like this:

```powershell
$Drivemappings = @( #Create a line below for each drive mapping that needs to be created.
    @{"includeSecurityGroup" = "FOLDERPERM_FULL-ACCESS" ; "excludeSecurityGroup" = "" ; "driveLetter" = "T" ; "UNCPath" = "\\skunklab.co.uk\dfs\Shared"},
    @{"includeSecurityGroup" = "FOLDERPERM_ALL-STAFF" ; "excludeSecurityGroup" = "FOLDERPERM_FULL-ACCESS" ; "driveLetter" = "T" ; "UNCPath" = "\\skunklab.co.uk\dfs\shared\SHARED ACCESS"}
)
```

You can add as many lines in the **$Drivemappings** variable as you have groups that need mapping, just make sure that the final line doesn't have a comma at the end of the line.

Next we create the connection to Graph API. I use the code from Lee's blog earlier and it worked first time:

```powershell
# Add required assemblies
Add-Type -AssemblyName System.Web, PresentationFramework, PresentationCore

# Scope - Needs to include all permisions required separated with a space
$scope = "User.Read.All Group.Read.All" # This is just an example set of permissions

# Random State - state is included in response, if you want to verify response is valid
$state = Get-Random

# Encode scope to fit inside query string
$scopeEncoded = [System.Web.HttpUtility]::UrlEncode($scope)

# Redirect URI (encode it to fit inside query string)
$redirectUriEncoded = [System.Web.HttpUtility]::UrlEncode($redirectUri)

# Construct URI
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$redirectUriEncoded&response_mode=query&scope=$scopeEncoded&state=$state"

# Create Window for User Sign-In
$windowProperty = @{
    Width  = 500
    Height = 700
}

$signInWindow = New-Object System.Windows.Window -Property $windowProperty

# Create WebBrowser for Window
$browserProperty = @{
    Width  = 480
    Height = 680
}

$signInBrowser = New-Object System.Windows.Controls.WebBrowser -Property $browserProperty

# Navigate Browser to sign-in page
$signInBrowser.navigate($uri)

# Create a condition to check after each page load
$pageLoaded = {

    # Once a URL contains "code=*", close the Window
    if ($signInBrowser.Source -match "code=[^&]*") {

        # With the form closed and complete with the code, parse the query string

        $urlQueryString = [System.Uri]($signInBrowser.Source).Query
        $script:urlQueryValues = [System.Web.HttpUtility]::ParseQueryString($urlQueryString)

        $signInWindow.Close()

    }
}

# Add condition to document completed
$signInBrowser.Add_LoadCompleted($pageLoaded)

# Show Window
$signInWindow.AddChild($signInBrowser)
$signInWindow.ShowDialog()

# Extract code from query string
$authCode = $script:urlQueryValues.GetValues(($script:urlQueryValues.keys | Where-Object { $_ -eq "code" }))

if ($authCode) {

    # With Auth Code, start getting token

    # Construct URI
    $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    # Construct Body
    $body = @{
        client_id    = $clientId
        scope        = $scope
        code         = $authCode[0]
        redirect_uri = $redirectUri
        grant_type   = "authorization_code"
    }

    # Get OAuth 2.0 Token
    $tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body

    # Access Token
    $token = ($tokenRequest.Content | ConvertFrom-Json).access_token

}
else {

    Write-Error "Unable to obtain Auth Code!"

}
```

Now we need to use the token we generated and query the Graph API to get the list of groups that our user is a member of

```powershell
$uri = "https://graph.microsoft.com/v1.0/me/memberOf"
$method = "GET"

# Run Graph API query
$query = Invoke-WebRequest -Method $method -Uri $uri -ContentType "application/json" -Headers @{Authorization = "Bearer $token"} -ErrorAction Stop
$output = ConvertFrom-Json $query.Content
$usergroups = @()
foreach ($group in $output.value) {
    $usergroups += $group.displayName
}
```

Finally we need to check if the user can see the domain (there's no point executing the script if they are out of the office) and for each group the user is a member of, map the drives using the New-PSDrive cmdlet

```powershell
$connected=$false
$retries=0
$maxRetries=3

Write-Output "Starting script..."
do {
    if (Resolve-DnsName $dnsDomainName -ErrorAction SilentlyContinue) {
        $connected=$true
    }
    else {
        $retries++
        Write-Warning "Cannot resolve: $dnsDomainName, assuming no connection to fileserver"
        Start-Sleep -Seconds 3
        if ($retries -eq $maxRetries){
            Throw "Exceeded maximum numbers of retries ($maxRetries) to resolve dns name ($dnsDomainName)"
        }
    }
}
while( -not ($Connected))

Write-Output $usergroups

$drivemappings.GetEnumerator()| ForEach-Object {
    Write-Output $PSItem.UNCPath
    if(($usergroups.contains($PSItem.includeSecurityGroup)) -and ($usergroups.contains($PSItem.excludeSecurityGroup) -eq $false)) {
        Write-Output "Attempting to map $($Psitem.DriveLetter) to $($PSItem.UNCPath)"
        New-PSDrive -PSProvider FileSystem -Name $PSItem.DriveLetter -Root $PSItem.UNCPath -Persist -Scope global
    }
}
```

That's it, the script when executed will run as the user and map the drives. We now need to host this script somewhere that can be referenced from any device with an Internet connection.

#### Uploading the script to Azure

We will host the drive mapping script in a blob store in Azure. Sign into your Azure Portal and click on Storage Accounts and create a new one with the following settings

![storage account](/images/6-storageacct.jpg)

Once created we need to add a **Container** that will store the script

![container](/images/7-createcontainer-300x210.jpg)

and finally we upload the script to the container

![ipload file](/images/8-uploadscript-300x207.jpg)

Once uploaded we need to get the URL for the script so we can use this in the Intune script later.

![](/images/9-url-300x253.jpg)

### The Intune Script

Now that we have our drive mapping script and its uploaded to the Azure blob, we need a way of calling this every time a user signs into the computer. This script will:

- Be run from the Intune Management Extension as the SYSTEM account
- Create a new Scheduled Task that will execute a hidden PowerShell window at logon which will download and run the previous script

The only variable we need to change in this script is the URL to the drive mapping script and the name of the scheduled task that is created. The whole script looks like:

```powershell
<#
    DESCRIPTION:    Create a Scheduled Task to run at User Login that executes
                    that executes a powershell script stored in an Azure blob storage account
    AUTHOR:         Matt White (matthewwhite@itlab.com
    DATE:           2019-04-06
    USAGE:          Edit the values in the first section with respect to your link to the script
                    Add in the name of the scheduled task that you want to be called
                    Uplod the script to Intune to execute as a system context script

#>

<#
    DO NOT EDIT THIS SECTION
#>

$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $(Get-Date).ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile -Append

<#
    END SECTION
#>

<#
    Setup Script Variables
#>

$scriptLocation = "https://#############.blob.core.windows.net/pub-intune-scripts/DriveMapping.ps1" #enter the path to your script StorageAccounts->"account"->Blobs->"container"->"script"->URL
$taskName = "Map Network Drives" #enter the name for your scheduled task

<#
    END SECTION
#>

<#
    Setup the Scheduled Task
#>


$schedTaskCommand = "Invoke-Expression ((New-Object Net.WebClient).DownloadString($([char]39)$($scriptLocation)$([char]39)))"
$schedTaskArgs= "-ExecutionPolicy Bypass -windowstyle hidden -command $($schedTaskCommand)"
$schedTaskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
If (($schedTaskExists)-and (Get-ScheduledTask -TaskName $taskName).Actions.arguments -eq $schedTaskArgs){
    Write-Output "Task Exists and names match"
}
Else {
    if($schedTaskExists) {
        Write-Output "OldTask: $((Get-ScheduledTask -TaskName $taskName).Actions.arguments)"
        Write-Output "NewTask: $($schedTaskCommand)"
        Write-Output "Deleting Scheduled Task"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Output "Creating Schdeuled Task"
    $schedTaskAction = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $schedTaskArgs
    $schedTaskTrigger = New-ScheduledTaskTrigger -AtLogon
    $schedTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
    $schedTaskPrincipal = New-ScheduledTaskPrincipal -GroupId S-1-5-32-545
    $schedTask = New-ScheduledTask -Action $schedTaskAction -Settings $schedTaskSettings -Trigger $schedTaskTrigger -Principal $schedTaskPrincipal -ErrorVariable $NewSchedTaskError
    Register-ScheduledTask -InputObject $schedTask -TaskName $taskName -ErrorVariable $RegSchedTaskError
}

Stop-Transcript
```

This now needs to be added to Intune so that it can be executed on the devices. Navigate to Intue, Device Configuration, PowerShell scripts and add a new script

![](/images/10-createintunescript-229x300.jpg)

Once the file is uploaded, click on Configure to check how the script should be run

![](/images/11-intunesettings-300x140.jpg)

Once complete click **Save** and the script will be uploaded.

Finally we need to assign the script to users or devices. In my example all my computers are deployed via Autopilot so I assign the script to my Autopilot security groups which contain all the computer accounts.

## The end result

When the Intune script runs on the endpoint it will check if the scheduled task exists and whether the script it will execute matches what was in any previous configuration. If there is no task, it is created and if there are changes, the old task is deleted and a new task is created.

When a user signs in they will see a popup window as the auth token is generated and then, if they are connected to the corporate network, their network drives will be mapped.

If you need to change the drives that a user has access to (either as you migrate to a more appropritae cloud service or you change the servers that host the data) simply amend the script in the blob store and the new drives will be mapped at logon.

The Intune script can be re-used for any other code that you want to run at user logon, simply reference the link to the script in the blob store and the name of the scheduled task you wish to use.

## The scripts in full

### Drive Mapping Script

```powershell
<#
    DESCRIPTION:    Iterate through a list of drive mappings, match the groups to AzureAD groups
                    Where they match connect to the UNC path
    AUTHOR:         Matt White (matthewwhite@itlab.com)
    DATE:           2019-04-06
    USAGE:          Edit the values in the first section with respect to your link to the script
                    Add in the name of the scheduled task that you want to be called
                    Uplod the script to Intune to execute as a system context script

#>

<#
    DO NOT EDIT THIS SECTION
#>

$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $(Get-Date).ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile -Append

<#
    END SECTION
#>

$clientId = "73b7bec7-####-####-####-############" #This is the Client ID for your Application Registration in Azure AD
$tenantId = "3b7b2097-####-####-####-############" # This is the Tenant ID of your Azure AD Directory
$redirectUri = "https://login.microsoftonline.com/common/oauth2/nativeclient" # This is the Return URL for your Application Registration in Azure AD

$dnsDomainName = "skunklab.co.uk" #This is the internal name of your AD Forest


$Drivemappings = @( #Create a line below for each drive mapping that needs to be created.
    @{"includeSecurityGroup" = "FOLDERPERM_FULL-ACCESS" ; "excludeSecurityGroup" = "" ; "driveLetter" = "T" ; "UNCPath" = "\\skunklab.co.uk\dfs\shared"},
    @{"includeSecurityGroup" = "FOLDERPERM_ALL-STAFF" ; "excludeSecurityGroup" = "FOLDERPERM_FULL-ACCESS" ; "driveLetter" = "T" ; "UNCPath" = "\\skunklab.co.uk\dfs\shared\sharedaccess"}
)

# Add required assemblies
Add-Type -AssemblyName System.Web, PresentationFramework, PresentationCore

# Scope - Needs to include all permisions required separated with a space
$scope = "User.Read.All Group.Read.All" # This is just an example set of permissions

# Random State - state is included in response, if you want to verify response is valid
$state = Get-Random

# Encode scope to fit inside query string
$scopeEncoded = [System.Web.HttpUtility]::UrlEncode($scope)

# Redirect URI (encode it to fit inside query string)
$redirectUriEncoded = [System.Web.HttpUtility]::UrlEncode($redirectUri)

# Construct URI
$uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize?client_id=$clientId&response_type=code&redirect_uri=$redirectUriEncoded&response_mode=query&scope=$scopeEncoded&state=$state"

# Create Window for User Sign-In
$windowProperty = @{
    Width  = 500
    Height = 700
}

$signInWindow = New-Object System.Windows.Window -Property $windowProperty

# Create WebBrowser for Window
$browserProperty = @{
    Width  = 480
    Height = 680
}

$signInBrowser = New-Object System.Windows.Controls.WebBrowser -Property $browserProperty

# Navigate Browser to sign-in page
$signInBrowser.navigate($uri)

# Create a condition to check after each page load
$pageLoaded = {

    # Once a URL contains "code=*", close the Window
    if ($signInBrowser.Source -match "code=[^&]*") {

        # With the form closed and complete with the code, parse the query string

        $urlQueryString = [System.Uri]($signInBrowser.Source).Query
        $script:urlQueryValues = [System.Web.HttpUtility]::ParseQueryString($urlQueryString)

        $signInWindow.Close()

    }
}

# Add condition to document completed
$signInBrowser.Add_LoadCompleted($pageLoaded)

# Show Window
$signInWindow.AddChild($signInBrowser)
$signInWindow.ShowDialog()

# Extract code from query string
$authCode = $script:urlQueryValues.GetValues(($script:urlQueryValues.keys | Where-Object { $_ -eq "code" }))

if ($authCode) {

    # With Auth Code, start getting token

    # Construct URI
    $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    # Construct Body
    $body = @{
        client_id    = $clientId
        scope        = $scope
        code         = $authCode[0]
        redirect_uri = $redirectUri
        grant_type   = "authorization_code"
    }

    # Get OAuth 2.0 Token
    $tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body

    # Access Token
    $token = ($tokenRequest.Content | ConvertFrom-Json).access_token

}
else {

    Write-Error "Unable to obtain Auth Code!"

}

####
# Run Graph API Query to get group membership
####

$uri = "https://graph.microsoft.com/v1.0/me/memberOf"
$method = "GET"

# Run Graph API query
$query = Invoke-WebRequest -Method $method -Uri $uri -ContentType "application/json" -Headers @{Authorization = "Bearer $token"} -ErrorAction Stop
$output = ConvertFrom-Json $query.Content
$usergroups = @()
foreach ($group in $output.value) {
    $usergroups += $group.displayName
}

# Loop the Drive Mappings and check group membership

$connected=$false
$retries=0
$maxRetries=3

Write-Output "Starting script..."
do {
    if (Resolve-DnsName $dnsDomainName -ErrorAction SilentlyContinue) {
        $connected=$true
    }
    else {
        $retries++
        Write-Warning "Cannot resolve: $dnsDomainName, assuming no connection to fileserver"
        Start-Sleep -Seconds 3
        if ($retries -eq $maxRetries){
            Throw "Exceeded maximum numbers of retries ($maxRetries) to resolve dns name ($dnsDomainName)"
        }
    }
}
while( -not ($Connected))

Write-Output $usergroups

$drivemappings.GetEnumerator()| ForEach-Object {
    Write-Output $PSItem.UNCPath
    if(($usergroups.contains($PSItem.includeSecurityGroup)) -and ($usergroups.contains($PSItem.excludeSecurityGroup) -eq $false)) {
        Write-Output "Attempting to map $($Psitem.DriveLetter) to $($PSItem.UNCPath)"
        New-PSDrive -PSProvider FileSystem -Name $PSItem.DriveLetter -Root $PSItem.UNCPath -Persist -Scope global
    }
}

Stop-Transcript
```

### Intune Scheduled Task Script

```powershell
<#
    DESCRIPTION:    Create a Scheduled Task to run at User Login that executes
                    that executes a powershell script stored in an Azure blob storage account
    AUTHOR:         Matt White (matthewwhite@itlab.com
    DATE:           2019-04-06
    USAGE:          Edit the values in the first section with respect to your link to the script
                    Add in the name of the scheduled task that you want to be called
                    Uplod the script to Intune to execute as a system context script

#>

<#
    DO NOT EDIT THIS SECTION
#>

$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $(Get-Date).ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile -Append

<#
    END SECTION
#>

<#
    Setup Script Variables
#>

$scriptLocation = "https://###########.blob.core.windows.net/pub-intune-scripts/DriveMapping.ps1" #enter the path to your script StorageAccounts->"account"->Blobs->"container"->"script"->URL
$taskName = "Map Network Drives" #enter the name for your scheduled task

<#
    END SECTION
#>

<#
    Setup the Scheduled Task
#>


$schedTaskCommand = "Invoke-Expression ((New-Object Net.WebClient).DownloadString($([char]39)$($scriptLocation)$([char]39)))"
$schedTaskArgs= "-ExecutionPolicy Bypass -windowstyle hidden -command $($schedTaskCommand)"
$schedTaskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
If (($schedTaskExists)-and (Get-ScheduledTask -TaskName $taskName).Actions.arguments -eq $schedTaskArgs){
    Write-Output "Task Exists and names match"
}
Else {
    if($schedTaskExists) {
        Write-Output "OldTask: $((Get-ScheduledTask -TaskName $taskName).Actions.arguments)"
        Write-Output "NewTask: $($schedTaskCommand)"
        Write-Output "Deleting Scheduled Task"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Output "Creating Schdeuled Task"
    $schedTaskAction = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument $schedTaskArgs
    $schedTaskTrigger = New-ScheduledTaskTrigger -AtLogon
    $schedTaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
    $schedTaskPrincipal = New-ScheduledTaskPrincipal -GroupId S-1-5-32-545
    $schedTask = New-ScheduledTask -Action $schedTaskAction -Settings $schedTaskSettings -Trigger $schedTaskTrigger -Principal $schedTaskPrincipal -ErrorVariable $NewSchedTaskError
    Register-ScheduledTask -InputObject $schedTask -TaskName $taskName -ErrorVariable $RegSchedTaskError
}

Stop-Transcript
```

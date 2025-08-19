---
title: "Intune: Automatically set timezone on new device build"
pubDate: "2019-04-18"
categories:
  - "intune"
  - "it"
tags:
  - "computer"
  - "intune"
  - "microsoft"
  - "powershell"
  - "script"
heroImage: "/blog-intune-timezone.png"
description: "Technote that provides a script to discover the geo location of a device enrolling into Intune and use that geo location to map that to a valid timezone and set that on the client device"
---

In Michael Niehaus' recent blog on [Configuring Windows 10 defaults via Windows Autopilot using an MSI](https://techcommunity.microsoft.com/t5/Windows-IT-Pro-Blog/Configuring-Windows-10-defaults-via-Windows-Autopilot-using-an/ba-p/457063) he talked about the ability to set the Time Zone of the device based on a variable in the [Config.xml](https://github.com/mtniehaus/AutopilotBranding/blob/master/AutopilotBranding/Config.xml) file. One of the comments on the blog asked whether it would be possible to set the time zone based on where the device was at the time of setup rather than based on an attribute in the file.

Whilst Windows 10 has a feature to detect the time zone automatically I have found on occasion with devices that this doesn't always work out of the box and the time zone remains in a region that is not accurate for where the device is. This should be relatively simple to automate if we can geo-locate the public IP address and match those coordinates to a valid time zone. For this I am using two web services:

1. [https://ipstack.com](https://ipstack.com) - this will map the public IP address to a geo-location including coordinates, you get access to 10,000 queries a month for free

2. [Bing Maps API](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/bingmaps.mapapis) - this will return the correct time zone in a valid Windows format that can be used in the script to set the time zone on the device, there is a free tier here that also gives you 10,000 queries per month without charge

## The Script

The script will execute the following in sequence:

1. Attempt to get the coordinates of the IP address you are using via the IPStack API

2. If successful, attempt to find the time zone from the Bing Maps API

3. Compare the value of the current time zone on the machine with the response from the Bing Maps API

4. Change the time zone on the machine

The only variable you should need to change in the script are the two lines that will contain your API keys helpfully called **ipStackAPIKey** and **bingMapsAPIKey**.

You can choose now to either save the file as a script to run once in Intune, or, incorporate this into Michael's MSI. If you wanted the script to run every time the machine starts up, you could adapt the Logon script from my recent post on [Mapping legacy files shares for Azure AD joined devices](/blog/mapping-legacy-file-shares).

```powershell
<#
    SCRIPT: Set-TimeZoneGeoIP.ps1
    DESCRIPTION: Based on the public egress IP obtain geoLocation details and match to a time zone
                 Once obtained set the Time Zone on the destination computer
#>

<#
    SETUP ATTRIBUTES
#>
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\TimeZoneAPI-" + $(Get-Date).ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile -Append


$ipStackAPIKey = "##########" #used to get geoCoordinates of the public IP. get the API key from https://ipstack.com
$bingMapsAPIKey = "##########" #Used to get the Windows TimeZone value of the location coordinates. get teh API key from https://azuremarketplace.microsoft.com/en-us/marketplace/apps/bingmaps.mapapis

<#
    Attempt to get Lat and Long for current IP
#>

Write-Output "Attempting to get coordinates from egress IP address"
try {
    $geoIP = Invoke-RestMethod -Uri "http://api.ipstack.com/check?access_key=$($ipStackAPIKey)" -ErrorAction SilentlyContinue -ErrorVariable $ErrorGeoIP
}
Catch {
    Write-Output "Error obtaining coordinates or public IP address, script will exit"
    Exit
}

Write-Output "Detected that $($geoIP.ip) is located in $($geoIP.country_name) at $($geoIP.latitude),$($geoIP.longitude)"
Write-Output "Attempting to find Corresponding Time Zone"
try {
    $timeZone = Invoke-RestMethod -Uri "https://dev.virtualearth.net/REST/v1/timezone/$($geoIP.latitude),$($geoIP.longitude)?key=$($bingMapsAPIKey)" -ErrorAction Stop -ErrorVariable $ErrortimeZone
}
catch {
    Write-Output "Error obtaining Timezone from Bing Maps API. Script will exit"
    Exit
}
$correctTimeZone = $TimeZone.resourceSets.resources.timeZone.windowsTimeZoneId
$currentTimeZone = $(Get-TimeZone).id
Write-Output "Detected Correct time zone as $($correctTimeZone), current time zone is set to $($currentTimeZone)"
if ($correctTimeZone -eq $currentTimeZone) {
    Write-Output "Current time zone value is correct"
}
else {
    Write-Output "Attempting to set timezone to $($correctTimeZone)"
    Set-TimeZone -Id $correctTimeZone -ErrorAction SilentlyContinue -ErrorVariable $ErrorSetTimeZone
    Write-Output "Set Time Zone to: $($(Get-TimeZone).id)"
}

Stop-Transcript
```

The script will output to a folder in %PROGRAMDATA% called Intune-PowerShell-Logs.

Hopefully you will find this useful to configure time zone information on your Modern Workplace machines.

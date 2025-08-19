---
title: "Reporting on AD users last password change"
pubDate: "2015-10-27"
categories:
  - "it"
tags:
  - "active-directory"
  - "computer"
  - "powershell"
  - "reporting"
  - "script"
heroImage: "/blog-intune-tech.png"
description: "Short Technote on how to use PowerShell to report on when users last changed their password"
---

As part of some recent work to assist a client with reporting on their active users and the dates those users last changed their passwords I evolved a script written by Carl Gray here ([PowerShell: Get-ADUser to retrieve password last set and expiry information](http://www.oxfordsbsguy.com/2013/11/25/powershell-get-aduser-to-retrieve-password-last-set-and-expiry-information/)) to generate a short PowerShell script that will report the enabled Active Directory users and the date that they last set their password.

Copy the code below and save on your server as Get-PasswordLastChange.ps1 and then run from the command line. Script will produce a CSV file and save it in the same directory as the script

```powershell
#Configure Output File
$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$timestamp = Get-Date -UFormat %Y%m%d-%H%M
$random = -join(48..57+65..90+97..122 | ForEach-Object {[char]$_} | Get-Random -Count 6)
$reportfile = "$mydir\PasswordLastSet-$timestamp-$random.csv"
Import-Module ActiveDirectory

Get-ADUser -filter * -properties passwordlastset, passwordneverexpires | `
Where {($_.userAccountControl -band 2) -eq $False} | `
sort-object name | `
select-object Name, passwordlastset, passwordneverexpires | `
Export-csv -path $reportfile -NoTypeInformation

Write-Host -ForegroundColor White "Report written to $reportfile in current path."
Get-Item $reportfile
```

---
title: "Reporting on inactive AD user accounts"
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
description: "Short technote demonstrating how to use PowerShell to report on inactive user accounts"
---

In the second quick article following my reporting requirement this time is to report on the enabled user accounts that have not logged in in the past X days. I took the Search-ADAccount cmdlet and created some filters to exclude disabled accounts as well as enable a parameter to be passed with the script to specify the maximum age, in days, of a user account (default is 90 days)

Save the below script as Get-InactiveAccounts.ps1

```powershell
Param(
    [int]$InactiveDays = 90
)
#Configure Output File
$myDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$timestamp = Get-Date -UFormat %Y%m%d-%H%M
$random = -join(48..57+65..90+97..122 | ForEach-Object {[char]$_} | Get-Random -Count 6)
$reportfile = "$mydir\InactiveAccounts-$timestamp-$random.csv"
Import-Module ActiveDirectory

Search-ADAccount -UsersOnly -AccountInactive -TimeSpan "$InactiveDays" | `
Get-ADUser -Properties Name, sAMAccountName, givenName, sn, userAccountControl,lastlogondate | `
Where {($_.userAccountControl -band 2) -eq $False} | Select Name, sAMAccountName, givenName, sn,LastLogonDate | `
Export-Csv $reportfile -NoTypeInformation

Write-Host -ForegroundColor White "Report written to $reportfile in current path."
Get-Item $reportfile
```

To execute the script run .\\Get-InactiveAccounts.ps1 to report on accounts older than 90 days or use the InactiveDays parameter to specify the age of accounts to report (eg .\\Get-InactiveAccounts.ps1 -InactiveDays 180)

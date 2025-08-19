---
title: "Deploy custom fonts to Intune managed devices"
pubDate: "2019-06-13"
categories:
  - "intune"
  - "it"
tags:
  - "fonts"
  - "intune"
  - "modern-workplace"
  - "powershell"
  - "scripting"
  - "windows-10"
heroImage: "/blog-intune-tech.png"
description: "Technote that describes how to package and deploy font files to Intune managed Windows devices using the Win32App packaging construct"
---

As part of a recent piece of work deploying a Modern Workplace solution for a customer, I was asked how could we deploy their corporate fonts to all machines so that corporate branding was maintained across documents that were produced in the organisation. Looking online there are several scripts that allow you to deploy an individual font ([Deploying an embedded file (FONT) in a Powershell script through Intune MDM](https://www.lieben.nu/liebensraum/2019/01/deploying-an-embedded-file-font-in-a-powershell-script-through-intune-mdm/)) however I had two font families with a total of 15 fonts that needed to be deployed. Encoding these files into Base64 would hit the limit of the PowerShell scripts that Intune Management Extension could execute so I had to look for an alternative.

The logical solution was to build an "application" that can deploy the fonts using the Win32app functionality in Intune and then push them as Required to the Intune managed computers. I would need several components for this:

- An Installer to copy the fonts into the right target location on the devices (whilst you can copy them to C:\\Windows\\Fonts there is a bit more configuration to complete the install)

- An Uninstaller to remove the fonts if they were no longer required (this is more for completeness and clean up in the future rather than a full requirement for the customer)

- The fonts in a logical format so they can be iteratively installed.

The install and uninstall process was quickly solved when I found this blog for [Adding and Removing Fonts with Windows PowerShell](https://blogs.technet.microsoft.com/deploymentguys/2010/12/04/adding-and-removing-fonts-with-windows-powershell/). The script enables a single font, or all fonts in a particular folder to be installed. I made a tweak to complete this recursively over my install folder so that I could package all the fonts in a single application changing the relevant lines in the source script from this:

```powershell
elseif ((Test-Path $path -PathType Container) -eq $true)
{
    $bErrorOccured = $false

    foreach ($file in (Get-Childitem $path)) {

        if ($hashFontFileTypes.ContainsKey($file.Extension)) {
            $retVal = Add-SingleFont (Join-Path $path $file.Name)
            if ($retVal -ne 0) {
                $bErrorOccured = $true

            }

        }
        else {
            "`'$(Join-Path $path $file.Name)`' not a valid font file type"
            ""
        }
    }

    If ($bErrorOccured -eq $true) {
        exit 1
    }
    else {
        exit 0
    }
}
```

to this

```powershell
elseif ((Test-Path $path -PathType Container) -eq $true) {
    $bErrorOccured = $false
    write-host $path
    foreach($file in (Get-Childitem $path -Recurse)) {
        if ($hashFontFileTypes.ContainsKey($file.Extension)) {
            $retVal = Add-SingleFont $($file.Fullname)
            if ($retVal -ne 0) {
                $bErrorOccured = $true
                Write-Output "Install of $($file.name) Failed"
            }
            else { Write-Output "Install of $($file.name) Successful" }
        }
        else {
            "`'$(Join-Path $path $file.Name)`' not a valid font file type"
            ""
        }
    }
    If ($bErrorOccured -eq $true) { exit 1 }
    else { exit 0 }
}
```

To make the install process easier I have created some single line scripts that will take all the files in the **Fonts** subfolder and call the Add-Font or Remove-Font script against them.

## install.cmd

```bat
powershell.exe -executionpolicy bypass -command "& '.\Add-Font.ps1'" -args "-path .\Fonts"
```

## uninstall.cmd

```bat
powershell.exe -executionpolicy bypass -command "foreach ($font in (Get-ChildItem -Path '.\Fonts' -Recurse)) { .\Remove-Font.ps1 -file $font.Name }"
```

Putting this all together I used the [Intune Win32 app packager](https://docs.microsoft.com/en-us/intune/apps-win32-app-management) to create a file that I can load into Intune to deploy to my users.

Want to use this yourself? You can download the script components from the following link. All you need to do is add the font files into the Fonts subfolder, run the wrapping process and then upload to Intune. [font-deployment](https://matthewjwhite.co.uk/wp-content/uploads/2019/06/font-deployment.zip)

Hope you find this useful to further customise your Modern Workplace deployments

---
title: "PowerShell software installation wrapper for Intune"
pubDate: "2017-12-18"
categories:
  - "intune"
  - "it"
tags:
  - "installer"
  - "intune"
  - "microsoft"
  - "modern-management"
  - "powershell"
  - "script"
  - "windows-10"
heroImage: "/blog-intune-tech.png"
description: "Conceptual blog post to demonstrate how to download and install applications to an Intune managed device before the Win32App construct was introduced. It uses the PowerShell script execution capability to download the binaries and then execute the installer"
---

A lot of my work recently has been working with Microsoft Intune to utilise Microsoft Modern Management constructs and principles to deliver a cloud first approach to provisioning new Windows 10 endpoints for an organisation.

Since Microsoft has migrated Intune management from the classic interface to the Azure Portal, the ability to execute installers for legacy line of business applications has been reduced. The idea is that the modern workplace is consuming data via apps from an app store and this is evident in Microsoft's support for the Microsoft Store for Business and Universal Windows Platform .appx package support in Intune however this is not always feasible in most workplaces. There are still legacy line of business applications that require an MSI or EXE based installer and whilst Intune will support Line of Business installers that are MSI based there is again a limitation that the MSI must contain all the code required to install the application. There is currently **no** support for EXE based installers in the Azure Portal for Intune.

Back at Microsoft Ignite 2017, Microsoft announced the availability of the Intune Management Extension and the support to execute PowerShell scripts on Windows 10 Endpoints via Microsoft Intune ([Read More](https://cloudblogs.microsoft.com/enterprisemobility/2017/09/27/whats-new-with-microsoft-intune-and-system-center-configuration-manager-ignite-2017/)). This got me thinking about how to extend the functionality of Microsoft Intune to deliver a more traditional (MDT / SCCM) provisioning process for legacy applications on modern managed Windows 10 devices.

If you could store your legacy line of business applications in a web accessible location (with appropriate security controls to prevent unauthorised access) you could then utilise the Intune Management Extension and PowerShell scripts to download the application install payload to a temporary location and then execute the payload to overcome the limitation of the Intune portal.

Looking around the Internet I came across this [blog post](https://www.petervanderwoude.nl/post/combining-the-powers-of-the-intune-management-extension-and-chocolatey/) by MVP Peter van der Woude which integrates the [Chocolatey](https://chocolatey.org) package manager and Intune. With a bit of reworking I amended the PowerShell code to download and install the AEM agent onto a target machine.

```powershell
$URL = "https://domain.com/path/to/installer.exe"
$InstallerPath = "C:\Temp\Installers"
$File = "TempFile.exe"
$Path = $installerPath + "\" + $File

$InstallCheck = Join-Path ([System.Environment]::GetFolderPath("ProgramFilesX86")) "Centrastage\cagservice.exe"

if (!(Test-Path -PathType Container -Path $insatllerPath)) {
    Try {
        New-Item $installerPath -ItemType Directory -ErrorAction Stop
    }
    Catch {
        Throw "Failed to create Installer Directory"
    }
}

if(!(Test-Path $installCheck)) {
     try {
        $down = New-Object System.Net.WebClient
        $down.DownloadFile($URL,$Path)
        $exec = New-Object -com shell.application
        $exec.shellexecute($Path)
     }
     catch {
         Throw "Failed to install Package"
     }
}
```

Save the PowerShell script and then add to Intune as outlined in Peter's blog post and wait for the code to execute on your endpoint. The process can be extended to run any executable based installer.

Whilst this is a fairly simplistic example, the concept could be extended to download a compressed archive, extract and then execute the installer as required.

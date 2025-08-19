---
title: "Nagios/Opsview: Check Symantec AV Definitions"
pubDate: "2010-03-01"
categories:
  - "it"
  - "monitoring"
tags:
  - "anti-virus"
  - "nagios"
  - "nrpe"
  - "opsview"
  - "symantec"
heroImage: "/blog-monitoring-header.png"
description: "Historical Technote that describes how to check the age of Symantec Endpoint Protection Antivirus definitions and report that data back to a monitoring service such as Nagios or Opsview"
---

This morning whilst deploying a modified version of the [Symantec Anti-Virus check](http://www.monitoringexchange.org/inventory/Check-Plugins/Operating-Systems/Windows-NRPE/Symantec-Anti-virus-check) from [MonitoringExchange.org](http://www.monitoringexchange.org) I noticed that on my 64-bit hosts that the check was not returning the correct data and instead of the expected output I was receiving the following error code:

```
check_av.vbs(51, 1) Microsoft VBScript runtime error: Type mismatch: 'strValue'
```

Initially I thought this could be a change due to the new installs being Symantec Endpoint Protection compared to the previous times I had implemented this using Symantec Anti-Virus 10.x but the SEP installs on the 32-bit systems were working fine however the 64-bit versions were not.

A quick look in the registry showed me that the value that is read by the script is not there on the 64-bit version and has been moved to another location (HKEY_LOCAL_MACHINESOFTWAREWow6432NodeSymantecSharedDefsDefWatch). I sat down with the script and quickly wrote in some extra code that would allow me to change the search path depending on the Operating System Architecture. I also added in some more error checking so if the key didnt exist then rather than exiting with an OK status it returns an UNKNOWN status and a relevant error message.

As I use [NSClient++](http://www.nsclient.org) to enable me to monitor my Windows servers I simply save the script to the NSClient++scripts folder and add the following line into my NSCI.ini under \[NRPE Handlers\]

```
check_av=cscript.exe //NoLogo scriptscheck_av.vbs /W:$ARG1$ /c:$ARG2$
```

Then from within Nagios or Opsview define the command for check_nrpe

`check_nrpe -H $HOSTADDRESS$ -c check_av -a 2 3`

The full script is listed below and is also available on Monitoring Exchange ([link](https://www.monitoringexchange.org/inventory/Check-Plugins/Operating-Systems/Windows-NRPE/check_symantec_av)):

```vb
' Script: check_av.vbs
' Author: Matt White
' Version: 1.1
' Date: 01-03-2010
' Details: Check the current definitions for Symantec AntiVirus are within acceptable bounds
' Usage: cscript /nologo check_av.vbs -w:<days> -c:<days>

' Define Constants for the script exiting
Const intOK = 0
Const intWarning = 1
Const intCritical = 2
Const intUnknown = 3

' Create required objects
Set ObjShell = CreateObject("WScript.Shell")
Set ObjProcess = ObjShell.Environment("Process")

const HKEY_CURRENT_USER = &H80000001
const HKEY_LOCAL_MACHINE = &H80000002

Dim strKeyPath, strSymantecVer
Dim intWarnLevel, intCritLevel, intYear, intMonth , intDay, intVer_Major, intDateDifference
Dim year, Month , Day, Ver_Major
Dim arrValue

' Parse Arguments to find Warning and Critical Levels
If Wscript.Arguments.Named.Exists("w") Then
intWarnLevel = Cint(Wscript.Arguments.Named("w"))
Else
intWarnLevel = 2
End If

If Wscript.Arguments.Named.Exists("c") Then
intCritLevel = Cint(Wscript.Arguments.Named("c"))
Else
intCritLevel = 4
End If

' Determine CPU architecture for correct location of the registry key
strCPUArch = objProcess("PROCESSOR_ARCHITECTURE")
If InStr(1, strCPUArch, "x86") > 0 Then
strKeyPath = "SOFTWARESymantecSharedDefsDefWatch"
ElseIf InStr(1, strCPUArch, "64") > 0 Then
strKeyPath = "SOFTWAREWow6432NodeSymantecSharedDefsDefWatch"
End If

' Query Registry using WMI to obtain the definition value
Set oReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\.rootdefault:StdRegProv")
oReg.GetBinaryValue HKEY_LOCAL_MACHINE,strKeyPath,"DefVersion",arrValue

' If the query doesnt return an array Quit - Unknown
If isArray(arrValue) = vbFalse Then
Wscript.Echo "UNKNOWN - Unable to read Definitions from the Registry"
Wscript.Quit(intUnknown)
End If

' Generate output from the registry value
intYear = CLng("&H" & hex(arrValue(1)) & hex(arrValue(0)))
intMonth = CLng("&H" & hex(arrValue(3)) & hex(arrValue(2)))
intDay = CLng("&H" & hex(arrValue(7)) & hex(arrValue(6)))
intVer_Major = CLng("&H" & hex(arrValue(17)) & hex(arrValue(16)))
strSymantecVer= intYear & "-" & intMonth & "-" & intDay & " rev. " & intVer_Major
intDateDifference = DateDiff("d", intYear & "/" & intMonth & "/" & intDay, Date)

' Output current version and definition age as Performance data
Wscript.Echo("Current Definitions: " & strSymantecVer & " Which are " & intDateDifference & " days old" & "|age=" & intDateDifference)

If intDateDifference > intCritLevel Then
Wscript.Quit(intCritical)
ElseIf intDateDifference > intWarnLevel Then
Wscript.Quit(intWarning)
ElseIf intDateDifference <= intWarnLevel Then
Wscript.Quit(intOK)
End If
Wscript.Quit(intUnknown)
```

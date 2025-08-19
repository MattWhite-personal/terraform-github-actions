---
title: "Check E-Trust Antivirus Definitions"
pubDate: "2010-03-15"
categories:
  - "it"
  - "monitoring"
tags:
  - "anti-virus"
  - "ca"
  - "nagios"
  - "nrpe"
  - "opsview"
heroImage: "/blog-monitoring-header.png"
description: "Technote and Visual Basic script to check the live definition version of the E-Trust Antivirus package and when used in conjuction with Windows monitoring toolings in Nagios / Opsview report the age of the definitions and whether that is acceptable or not"
---

Following on from my Symantec AV check I have written a first version of a similar check for E-Trust virus definitions. The format and structure to the check is the same as [this check](http://www.matthewjwhite.co.uk/blog/2010/03/01/nagiosopsview-check-symantec-av-definitions/) but it should return the relevant information for Computer Assoicates E-Trust Antivirus product.

For details on installation and configuration please check out the previous post. For the source code please check out the details below. If you wish to download this from Monitoring Exchange please use [this link](https://www.monitoringexchange.org/edit/inventory/2009-check_etrust_av).

```vb
' Script: check_etrust_av.vbs
' Author: Matt White
' Version: 1.0
' Date: 12-03-2010
' Details: Check the current definitions for E-Trust AntiVirus are within acceptable bounds
' Usage: cscript /nologo check_etrust_av.vbs -w: -c:

' Define Constants for the script exiting
Const intOK = 0
Const intWarning = 1
Const intCritical = 2
Const intUnknown = 3

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

' Define Date Regular Expression
Const strDateRegExp = "(0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])[- /.](19|20)dd"

' Create required objects
Set objShell = CreateObject("Wscript.Shell")
Set ObjProcess = ObjShell.Environment("Process")
Set objRegExp = New RegExp
Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\.rootdefault:StdRegProv")

const HKEY_CURRENT_USER = &H80000001
const HKEY_LOCAL_MACHINE = &H80000002


' read the path of E-Trust Anti-Virus from the registry
strKeyPath = "SOFTWAREComputerAssociatesScanEnginePath"
objReg.GetStringValue HKEY_LOCAL_MACHINE,strKeyPath,"Engine",strScanEnginePath

If TypeName(StrScanEnginePath) = "Null" Then
  WScript.Echo "UKNOWN: Cannot read registry Info. Is E-Trust installed?"
  Wscript.Quit(intUnknown)
End If

'strScanEnginePath = ObjShell.RegRead("HKLMSOFTWAREComputerAssociatesScanEnginePathEngine")

' Determine CPU architecture for correct executable to run
strCPUArch = objProcess("PROCESSOR_ARCHITECTURE")
If InStr(1, strCPUArch, "x86") > 0 Then
strExecutable = "inocmd32.exe"
ElseIf InStr(1, strCPUArch, "64") > 0 Then
strExecutable = "inocmd64.exe"
End If


' If the path doesnt exist Exit with an Unknown status
If Len(StrScanEnginePath) = 0 Then
  Wscript.Echo "UNKNOWN: Unable to read registry path"
  Wscript.Quit(intUnknown)
End If

' Run the command and read the output into a string
Set objExec = objShell.Exec(strScanEnginePath & strExecutable & " /sig")
strVirusDefs = objExec.StdOut.ReadAll()

' Search the Virus definition for the date using Regular Expression
objRegExp.Pattern = strDateRegExp
objRegExp.Global = True
objRegExp.IgnoreCase = True
Set regExpMatch = objRegExp.Execute(strVirusDefs)

' If date not found in the output. Exit with a warning
If regExpMatch.Count = 0 Then
  Wscript.Echo "UNKNOWN: Unable to read date from the output"
  Wscript.Quit(intUnknown)
End If

intDateDifference = DateDiff("d",CDate(regExpMatch(0).Value), Date)

Wscript.Echo strVirusDefs
If intDateDifference > intCritLevel Then
  Wscript.Quit(intCritical)
ElseIf intDateDifference > intWarnLevel Then
  Wscript.Quit(intWarning)
ElseIf intDateDifference <= intWarnLevel Then
  Wscript.Quit(intOK)
End If
Wscript.Quit(intUnknown)

```

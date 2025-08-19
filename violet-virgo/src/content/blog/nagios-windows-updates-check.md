---
title: "Nagios Windows Updates check"
pubDate: "2011-07-19"
categories:
  - "it"
  - "monitoring"
tags:
  - "microsoft"
  - "monitoring"
  - "nagios"
  - "nsclient"
  - "opsview"
  - "windows-update"
heroImage: "/blog-monitoring-header.png"
description: "Technote on how to use a VBScript to check the status of pending Windows Updates on a Windows Server and report back to a Nagios/Opsview monitoring instance using NRPE"
---

Following on from my post last night about the Windows Updates check on [MonitoringExchange](https://www.monitoringexchange.org/) a colleague reminded me that we acutally modified the script from there as we weren't looking for the names of updates to be listed but simply to get the total number of updates that are outstanding. The modified version of the script is listed below for reference and the source for this is at the following URL: [https://www.monitoringexchange.org/inventory/Check-Plugins/Operating-Systems/Windows-NRPE/Check-Windows-Updates](https://www.monitoringexchange.org/inventory/Check-Plugins/Operating-Systems/Windows-NRPE/Check-Windows-Updates)

```vb
<job>
  <script language="VBScript">
    ' Parse command line switches for pending updates
    If Wscript.Arguments.Named.Exists("h") Then
      Wscript.Echo "Usage: check_win_updates.wsf /w:1 /c:2"
      Wscript.Echo "/w: - number of updates before warning status "
      Wscript.Echo "/c: - number of updates before critical status "
    End If
    If Wscript.Arguments.Named.Exists("w") Then
      intWarning = Cint(Wscript.Arguments.Named("w"))
    Else
      intWarning = 0
    End If
    If Wscript.Arguments.Named.Exists("c") Then
      intCritical = Cint(Wscript.Arguments.Named("c"))
    Else
      intCritical = 0
    End If
    Set objShell = CreateObject("WScript.Shell")
    Dim sysroot
    sysroot = objShell.ExpandEnvironmentStrings("%systemroot%")
    ' Check if the Server is pending a reboot and quit with warning
    Set objSysInfo = CreateObject("Microsoft.Update.SystemInfo")
    If objSysInfo.RebootRequired Then
      Wscript.Echo "Warning: Reboot required | updates=-1"
      Wscript.quit(1)
    End If
    ' Dump Software Dist Event log to variable for parsing
    Set objExec = objShell.Exec("cmd.exe /c type " & sysroot & "SoftwareDistributionReportingEvents.log")
    results = LCase(objExec.StdOut.ReadAll)
    res_split = Split(results, vbCrLf)
    Dim regEx
    Set regEx = New RegExp
    regEx.Pattern = "(.)S*s*S*s*S*s*ds*(d*)s*S*s*S*[0-9s]*S*s*S*s*.*t(.*)"
    regEx.IgnoreCase = true
    count = 1
    ReDim arrDyn(1)
    For Each zeile in res_split
      firstsign = regEx.Replace(zeile, "$1")
      If (firstsign = "{") Then
                number = regEx.Replace(zeile, "$2")
        finish = regEx.Replace(zeile, "$3")
                If (number = 147) Then
          count = count + 1
          ReDim Preserve arrDyn(count + 1)
                  arrDyn(count + 1) = finish
        End If
      End If
    Next
    mount_updates = -1
    For x = 0 to UBound(arrDyn)
      If x = UBound(arrDyn) Then
                      end_array = Split(arrDyn(x), " ")
                      mount_updates = end_array(UBound(end_array) - 1)
      End If
    Next
    ' Quit the script with the appropriate performance data
    mount_updates = Cint(mount_updates)
    If mount_updates = 0 Then
      Wscript.Echo "OK: There are no pending updates | updates=0"
      Wscript.Quit(0)
    ElseIf mount_updates >= intCritical Then
      Wscript.Echo "Critical: There are " & mount_updates & " updates pending | updates=" & mount_updates
      Wscript.Quit(2)
    ElseIf mount_updates >= intWarning Then
      Wscript.Echo "Warning: There are " & mount_updates & " updates pending | updates=" & mount_updates
      Wscript.Quit(1)
    ElseIf mount_updates < intWarning Then
      Wscript.Echo "OK: There are " & mount_updates & " updates pending | updates=" & mount_updates
      Wscript.Quit(0)
    Else
      Wscript.Echo "Unknown: There has been an error"
      Wscript.Quit(3)
    End If
    Wscript.Echo "Unknown: There has been an error"
    Wscript.Quit(3)
  </script>
</job>
```

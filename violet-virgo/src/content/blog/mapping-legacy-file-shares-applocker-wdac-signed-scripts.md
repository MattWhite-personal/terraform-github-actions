---
title: "Mapping legacy file shares revisited: AppLocker, WDAC and signed scripts"
pubDate: "2026-11-22"
categories:
  - "intune"
  - "it"
tags:
  - "applocker"
  - "azure"
  - "code-signing"
  - "drive-mapping"
  - "intune"
  - "powershell"
  - "wdac"
  - "windows"
heroImage: "/blog-intune-tech.png"
description: "An update to my legacy file share mapping script for Entra joined devices. The new version works on devices protected by AppLocker or WDAC by signing the script so it runs in full language mode, and moves the drive map definitions out of the script into a JSON file in a storage account secured with Entra ID access control."
---

Back in 2019 I wrote about [mapping legacy file shares for Azure AD joined devices](/blog/mapping-legacy-files-shares-for-azure-ad-joined-devices) using a PowerShell script, a scheduled task and Microsoft Intune. Seven years later, I still get asked about it and, somewhat surprisingly, there are still plenty of customers with file servers that aren't going away any time soon.

What has changed is the security posture of the devices. Customers who were happy with a wide open PowerShell execution policy are now rolling out AppLocker or Windows Defender Application Control (WDAC), and the original script falls over in a number of places. This post covers three changes to the original approach:

1. Supporting environments where AppLocker or WDAC is enforced
2. Moving the drive maps out of the script and into a JSON file stored in a storage account (with a note on S3)
3. Code signing the script so that it runs in full language mode

If you haven't read the original post, it is worth a skim first as I won't repeat the Entra app registration steps in full.

## The Challenge

The original solution worked like this:

1. Intune runs a script as SYSTEM that creates a scheduled task
2. At user logon the scheduled task downloads the drive mapping script from a blob and runs it with `Invoke-Expression`
3. The script signs the user into Entra ID, calls the Graph API to list the groups they are a member of, then maps each drive where they match a group

When AppLocker or WDAC script enforcement is turned on, PowerShell drops into **Constrained Language Mode** for any script that isn't trusted. That breaks the original in a few ways:

- `Add-Type` is blocked, so the WPF sign-in window can't be created
- `Invoke-Expression` on a downloaded string is treated as untrusted content and runs constrained
- `-ExecutionPolicy Bypass` is no help, because language mode is enforced by the policy, not the execution policy
- Every change to the drive maps means editing, and in future re-signing, the whole script

There was also something that always bothered me about the original. The drive map definitions were baked into the script, so a change to a single drive letter meant touching code. It's far better to treat the drive maps as data.

## The Solution

My requirements for version two are:

- Everything from the original (Entra joined, dedicated or shared devices, drives processed sequentially)
- Runs in **Full Language Mode** on devices with AppLocker or WDAC enforced
- Drive maps are stored as data, separate from the code, and can be changed without re-signing the script
- No secrets or SAS tokens anywhere in the solution

### Language modes in a nutshell

You can check which mode a session is running in with:

```powershell
$ExecutionContext.SessionState.LanguageMode
```

On an unmanaged device this returns `FullLanguage`. With AppLocker script rules or a WDAC policy enforced, anything that isn't allowed by the policy returns `ConstrainedLanguage`. Scripts that are signed by a publisher that the policy trusts are allowed to run in full language mode, which is exactly what we want.

<!-- IMAGE PLACEHOLDER: Screenshot of PowerShell showing LanguageMode = ConstrainedLanguage for an unsigned script and FullLanguage for the signed script -->

### Drive maps as JSON

First, let's pull the drive maps out of the script. The same four attributes from the original post are used, they just live in a JSON file now:

```json
[
  {
    "includeSecurityGroup": "FOLDERPERM_FULL-ACCESS",
    "excludeSecurityGroup": "",
    "driveLetter": "T",
    "UNCPath": "\\\\skunklab.co.uk\\dfs\\shared"
  },
  {
    "includeSecurityGroup": "FOLDERPERM_ALL-STAFF",
    "excludeSecurityGroup": "FOLDERPERM_FULL-ACCESS",
    "driveLetter": "T",
    "UNCPath": "\\\\skunklab.co.uk\\dfs\\shared\\sharedaccess"
  }
]
```

Remember that JSON needs the backslashes in the UNC paths escaping, so every `\` becomes `\\`.

The signed script now only contains logic. Changing a drive map is an edit to a text file in a storage account, with no need to re-sign anything.

#### Where to store the JSON

I'm using an Azure storage account for this example, but the pattern is the same anywhere you can host a file behind authentication:

- **Azure Blob Storage with Entra ID access control (my choice)**: our users are already authenticating to Entra to find their group membership, so we can reuse that token to read the blob. Access is granted with an Azure RBAC role rather than a shared secret.
- **Amazon S3**: works well if the rest of your estate is in AWS. Use a bucket policy with IAM or federated access rather than presigned URLs. The Entra token can be exchanged using web identity federation, but it is noticeably more setup.
- **SAS token or presigned URL**: I would avoid this. A SAS token is a bearer secret that ends up in the scheduled task or script, can be copied by anyone with access to the device and is a pain to rotate. If you can use identity, use identity.

Create a storage account and a private container for the drive maps. Disable anonymous access and shared key access so that Entra ID is the only way in.

<!-- IMAGE PLACEHOLDER: Storage account creation, Advanced tab showing "Allow enabling anonymous access" and "Allow storage account key access" disabled -->

<!-- IMAGE PLACEHOLDER: Container created in the storage account with the drivemaps.json file uploaded -->

Next we need to grant the users read access to the blob. Rather than adding a role per user, assign **Storage Blob Data Reader** on the container to a security group that contains everyone who will receive the drive mapping.

<!-- IMAGE PLACEHOLDER: Container Access control (IAM) blade showing the Storage Blob Data Reader role assignment to the all users group -->

The last piece is the app registration from the original post. As well as the Graph permissions, the sign-in now also needs a delegated permission for the storage account. Under **API permissions** add **Azure Storage** and select **user_impersonation**, then grant admin consent as before.

<!-- IMAGE PLACEHOLDER: App registration API permissions showing Azure Storage user_impersonation and Microsoft Graph permissions with admin consent granted -->

#### Reading the drive maps in the script

The original script used a WPF window to sign in. As `Add-Type` is blocked for untrusted code, and I want the signed script to be as simple as possible, I've swapped that out for an authorization code flow that uses the default browser. You will still get a short sign-in prompt, or silent single sign-on where the device is Entra joined, but there is no WPF dependency.

I am not going to reproduce the whole sign-in routine again. The important change is that we now request two tokens, one for Graph and one for storage:

```powershell
$graphToken   = Get-EntraToken -Scope "https://graph.microsoft.com/GroupMember.Read.All"
$storageToken = Get-EntraToken -Scope "https://storage.azure.com/user_impersonation"
```

With the storage token we can read the JSON file. Storage requires the `x-ms-version` header when using bearer authentication:

```powershell
$mapsUri = "https://#############.blob.core.windows.net/drivemaps/drivemaps.json"

$headers = @{
    Authorization  = "Bearer $storageToken"
    "x-ms-version" = "2023-11-03"
}

$Drivemappings = Invoke-RestMethod -Method Get -Uri $mapsUri -Headers $headers -ErrorAction Stop
```

`Invoke-RestMethod` converts the JSON for us, so the rest of the script that iterates through `$Drivemappings` is unchanged from the original.

### Code signing the script

With the drive maps out of the way, the script is now stable code that rarely changes, which makes it a good candidate for signing.

It doesn't matter too much where the signing certificate comes from. What does matter is that the public key of the certificate (and its chain) is present in the right certificate stores on the endpoint, otherwise the signature won't be trusted and the script will be constrained. In practice that is:

- **Trusted Publishers**: so the signer is trusted to run scripts
- **Trusted Root Certification Authorities** (and Intermediate where applicable): so the chain validates

For this example I'm using the Azure public service, [Azure Artifact Signing](https://learn.microsoft.com/en-us/azure/artifact-signing/) (formerly Trusted Signing), which means there is no private key to protect and certificates are short lived and rotated for you. An internal CA, a commercial certificate or even a self-signed certificate in a lab will all work in the same way as long as the public key is deployed.

<!-- IMAGE PLACEHOLDER: Azure Artifact Signing account and certificate profile in the Azure portal -->

#### Signing the script

With a certificate profile created and the signing role assigned, sign the script using the signing tooling, for example in a GitHub Actions workflow or from a workstation:

```powershell
Invoke-ArtifactSigning -Endpoint "https://weu.codesigning.azure.net" `
    -CodeSigningAccountName "mw-signing" `
    -CertificateProfileName "mw-scripts" `
    -Files ".\DriveMapping.ps1" `
    -FileDigest SHA256
```

If you are using a certificate you hold the private key for, the built in cmdlet does the same job:

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
Set-AuthenticodeSignature -FilePath .\DriveMapping.ps1 -Certificate $cert -TimestampServer "http://timestamp.digicert.com"
```

Remember to timestamp the signature, otherwise the script stops being trusted the moment the certificate expires.

Any change to the script, even a space or a comment, invalidates the signature. This is the reason that moving the drive maps into JSON is so valuable.

<!-- IMAGE PLACEHOLDER: Properties of DriveMapping.ps1 showing the Digital Signatures tab, or Get-AuthenticodeSignature output showing Status Valid -->

#### Deploying the certificate with Intune

To get the public key onto the devices, export the signing certificate as a `.cer` file (public key only!) and deploy it with an Intune **Trusted certificate** profile.

1. In Intune navigate to **Devices**, **Configuration** and create a new profile
2. Choose **Windows 10 and later** and the **Templates** profile type, then **Trusted certificate**
3. Upload the `.cer` file and set the destination store to **Computer certificate store - Root** (or **Intermediate** for an intermediate CA)
4. Assign the profile to the same Autopilot group as the Intune script

<!-- IMAGE PLACEHOLDER: Intune Trusted certificate profile with the .cer uploaded and destination store selected -->

Trusted certificate profiles cannot target the Trusted Publishers store, so if your WDAC policy relies on the publisher being present there, push the certificate with a custom OMA-URI profile or a small remediation script. If you are allowing the signer through a policy rule as described below, this isn't required.

### Allowing the signer in AppLocker or WDAC

The final piece is telling the endpoint to trust scripts signed by our certificate. Rather than allowing paths or hashes (which would need changing every time the script is updated), add a signing rule.

**WDAC**: add a signer rule for the certificate to your policy. If you are using the WDAC Wizard, add a custom rule of type **Publisher**, choose the certificate and select the level that matches your certificate profile, for example the leaf or the PCA certificate with the subject name. Scripts signed by an allowed signer are permitted to run in full language mode.

<!-- IMAGE PLACEHOLDER: WDAC Wizard custom rule creation, Publisher rule for the signing certificate -->

Deploy the policy through Intune with the **App Control for Business** policy or a custom OMA-URI as you do now. Test in audit mode first and check the CodeIntegrity event log (`Microsoft-Windows-CodeIntegrity/Operational`) for events 3076 and 3077 before enforcing.

**AppLocker**: under **Script Rules** add a new **Allow** rule with the **Publisher** condition, point it at the signed script and move the slider to the level of the publisher you want to trust. PowerShell will run scripts allowed by an AppLocker rule in full language mode.

<!-- IMAGE PLACEHOLDER: AppLocker Script Rules showing the publisher Allow rule for the signing certificate -->

### The Intune Script

The final change is to the Intune script. The original script created a scheduled task that downloaded the script and ran it with `Invoke-Expression`. That will never be trusted under WDAC, as a string passed into `Invoke-Expression` has no signature to validate.

The updated script places the signed `.ps1` file on disk, and the scheduled task runs it with `-File`. As the script is signed by a trusted publisher it is allowed to run in full language mode. The task uses the `AllSigned` execution policy so an unsigned or tampered copy is refused.

SYSTEM has no user token to read from the Entra protected storage account, so in this example the signed script is packaged with the Intune deployment and copied to `C:\ProgramData\DriveMapping`.

```powershell
<#
    DESCRIPTION:    Copy a signed drive mapping script to the device and create a Scheduled Task
                    to run it at user logon
    AUTHOR:         Matt White
    DATE:           2026-11-22
    USAGE:          Package with DriveMapping.ps1 (signed) and deploy as a system context script
#>

$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $(Get-Date).ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile -Append

$installPath = "$env:ProgramData\DriveMapping"
$taskName = "Map Network Drives"

New-Item -Path $installPath -ItemType Directory -Force | Out-Null
Copy-Item -Path "$PSScriptRoot\DriveMapping.ps1" -Destination $installPath -Force

$schedTaskArgs = "-ExecutionPolicy AllSigned -WindowStyle Hidden -File `"$installPath\DriveMapping.ps1`""
$schedTaskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($schedTaskExists -and $schedTaskExists.Actions.Arguments -eq $schedTaskArgs) {
    Write-Output "Task exists and arguments match"
}
else {
    if ($schedTaskExists) {
        Write-Output "Deleting existing Scheduled Task"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Write-Output "Creating Scheduled Task"
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $schedTaskArgs
    $trigger   = New-ScheduledTaskTrigger -AtLogon
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Compatibility Win8
    $principal = New-ScheduledTaskPrincipal -GroupId S-1-5-32-545
    $task      = New-ScheduledTask -Action $action -Settings $settings -Trigger $trigger -Principal $principal
    Register-ScheduledTask -InputObject $task -TaskName $taskName
}

Stop-Transcript
```

<!-- TODO (Matt): confirm whether to package the signed script with the Intune script (Win32 app) or host it in blob storage. Plain Intune PowerShell scripts can't ship additional files, so this likely needs wrapping as a Win32 app. -->

<!-- IMAGE PLACEHOLDER: Intune deployment (Win32 app or script) showing assignment to the Autopilot device group -->

## The end result

When a user signs in, the scheduled task runs the signed script from `ProgramData`. The script checks the domain is reachable, signs the user into Entra, reads the drive maps JSON from the storage account using the user's own identity and the group membership from Graph, then maps the drives that match.

If you check the language mode in the transcript you will see it is `FullLanguage` even with AppLocker or WDAC enforced, and a user who isn't in the storage role group simply gets no drives rather than a failed script with a leaked token.

Changing a drive map is now an upload of a new `drivemaps.json`. No code change, no re-signing, and no redeploy to the endpoints. Only changes to the script logic need a new signature.

<!-- IMAGE PLACEHOLDER: Mapped drives in File Explorer on a device with WDAC enforced -->

## The scripts in full

### Drive Mapping Script

<!-- TODO (Matt): paste final tested, signed DriveMapping.ps1 here, including the Get-EntraToken function and the signature block -->

### Drive maps JSON

See the example earlier in this post.

### Intune Script

See the script earlier in this post.

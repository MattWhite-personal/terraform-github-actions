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
  - "wam"
  - "wdac"
  - "windows"
heroImage: "/blog-intune-tech.png"
description: "An update to my legacy file share mapping script for Entra joined devices. The new version works on devices protected by AppLocker or WDAC by signing the script so it runs in full language mode, signs users in with WAM, handles paged group membership results and reads the drive maps from a JSON file in a storage account secured with Entra ID access control."
---

Back in 2019 I wrote about [mapping legacy file shares for Azure AD joined devices](/blog/mapping-legacy-files-shares-for-azure-ad-joined-devices) using a PowerShell script, a scheduled task and Microsoft Intune. Seven years later, I still get asked about it and, somewhat surprisingly, there are still plenty of customers with file servers that aren't going away any time soon.

What has changed is the security posture of the devices. Customers who were happy with a wide open PowerShell execution policy are now rolling out AppLocker or Windows Defender Application Control (WDAC), and the original script falls over in a number of places. This post builds on the original and covers the following changes:

1. Supporting environments where AppLocker or WDAC is enforced
2. Moving the drive maps out of the script and into a JSON file stored in a storage account (with a note on S3)
3. Code signing the script so that it runs in full language mode
4. Signing users in with WAM, and fixing group lookups for users in lots of groups

I'm assuming you already have the pieces from the original post in place, so this post updates the existing script and Intune deployment rather than building everything from scratch. Where a new Azure or Intune resource is involved I've simply described what it needs to look like.

## The Challenge

The original solution worked like this:

1. Intune runs a script as SYSTEM that creates a scheduled task
2. At user logon the scheduled task downloads the drive mapping script from a blob and runs it with `Invoke-Expression`
3. The script signs the user into Entra ID in a WPF pop-up window, calls the Graph API to list the groups they are a member of, then maps each drive where they match a group

When AppLocker or WDAC script enforcement is turned on, PowerShell drops into **Constrained Language Mode** for any script that isn't trusted. That breaks the original in a few ways:

- `Add-Type` is blocked, so the WPF sign-in window can't be created
- `Invoke-Expression` on a downloaded string is treated as untrusted content and runs constrained
- `-ExecutionPolicy Bypass` is no help, because language mode is enforced by the policy, not the execution policy
- Every change to the drive maps means editing, and in future re-signing, the whole script

There are two other things that have always bothered me about the original. The drive map definitions were baked into the script, so a change to a single drive letter meant touching code. And the Graph call to `memberOf` only returns the first page of results, so users in a large number of groups could silently miss drives.

## The Solution

My requirements for version two are:

- Everything from the original (Entra joined, dedicated or shared devices, drives processed sequentially)
- Runs in **Full Language Mode** on devices with AppLocker or WDAC enforced
- Drive maps are stored as data, separate from the code, and can be changed without re-signing the script
- Seamless sign-in, ideally with no prompt at all on an Entra joined device
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

I'm using the storage account that already hosted the script in the original post, but the pattern is the same anywhere you can host a file behind authentication:

- **Azure Blob Storage with Entra ID access control (my choice)**: our users are already authenticating to Entra to find their group membership, so we can reuse that identity to read the blob. Access is granted with an Azure RBAC role rather than a shared secret.
- **Amazon S3**: works well if the rest of your estate is in AWS. Use a bucket policy with IAM or federated access rather than presigned URLs. The Entra token can be exchanged using web identity federation, but it is noticeably more setup.
- **SAS token or presigned URL**: I would avoid this. A SAS token is a bearer secret that ends up in the script or scheduled task, can be copied by anyone with access to the device and is a pain to rotate. If you can use identity, use identity.

Your storage account needs to be set up so that Entra ID is the only way in:

- Anonymous access and shared key access disabled
- The container holding `drivemaps.json` is private
- A security group containing everyone who receives the drive mapping is assigned **Storage Blob Data Reader** on the container

<!-- IMAGE PLACEHOLDER: Storage account configuration showing anonymous access and storage account key access disabled -->

<!-- IMAGE PLACEHOLDER: Container with drivemaps.json uploaded -->

<!-- IMAGE PLACEHOLDER: Container Access control (IAM) blade showing the Storage Blob Data Reader role assignment to the all users group -->

### Signing in with WAM

The original script used a WPF window to sign in, which is blocked in constrained language and, to be honest, never looked great. On an Entra joined device we can do much better by using the **Web Account Manager (WAM)**, the Windows broker that already holds the user's primary refresh token. With WAM the user gets single sign-on with no pop-up at all and falls back to a native Windows sign-in prompt only if they need to interact.

Azure PowerShell's `Az.Accounts` module uses WAM by default on Windows, so rather than hand rolling the OAuth flow I've replaced my copy of Lee's code with it. Install `Az.Accounts` on the endpoints (I include this in the installer package or deploy it as a Win32 app) and sign in with:

```powershell
Import-Module Az.Accounts

Connect-AzAccount -AuthScope "https://storage.azure.com" -ErrorAction Stop | Out-Null
```

Newer versions of the module return the access token as a `SecureString`, older ones return a plain string, so a small helper handles both. I then get one token for Graph and one for storage:

```powershell
function Get-AccessToken {
    param([string]$ResourceUrl)

    $token = (Get-AzAccessToken -ResourceUrl $ResourceUrl -ErrorAction Stop).Token
    if ($token -is [System.Security.SecureString]) {
        $token = [System.Net.NetworkCredential]::new('', $token).Password
    }
    $token
}

$graphToken   = Get-AccessToken -ResourceUrl "https://graph.microsoft.com"
$storageToken = Get-AccessToken -ResourceUrl "https://storage.azure.com"
```

If you would rather keep using your own app registration from the original post, the same approach works with MSAL.NET and the WAM broker package, you just need to supply your client ID and the delegated permissions for Graph and Azure Storage (**user_impersonation**) with admin consent granted.

<!-- IMAGE PLACEHOLDER: Existing app registration API permissions showing Azure Storage user_impersonation and Microsoft Graph permissions with admin consent (only needed if using your own app registration) -->

### Getting the groups, all of them

Graph returns group membership in pages. If a user is in more groups than fit in a single response, the response includes an `@odata.nextLink` property holding the URL of the next page, and the original script never followed it. Users in lots of nested or role groups could be missing drives with no error to explain why.

The updated function keeps following the link until there isn't one:

```powershell
function Get-UserGroups {
    param([string]$Token)

    $uri = 'https://graph.microsoft.com/v1.0/me/memberOf?$select=displayName&$top=999'
    $groups = [System.Collections.Generic.List[string]]::new()

    do {
        $response = Invoke-RestMethod -Method Get -Uri $uri -Headers @{ Authorization = "Bearer $Token" } -ErrorAction Stop
        foreach ($group in $response.value) {
            if ($group.displayName) { $groups.Add($group.displayName) }
        }
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    $groups
}

$usergroups = Get-UserGroups -Token $graphToken
```

### Reading the drive maps

With the storage token we can read the JSON file. Storage requires the `x-ms-version` header when using bearer authentication:

```powershell
$mapsUri = "https://#############.blob.core.windows.net/drivemaps/drivemaps.json"

$headers = @{
    Authorization  = "Bearer $storageToken"
    "x-ms-version" = "2023-11-03"
}

$Drivemappings = Invoke-RestMethod -Method Get -Uri $mapsUri -Headers $headers -ErrorAction Stop
```

`Invoke-RestMethod` converts the JSON for us, so the loop that iterates through `$Drivemappings` is unchanged from the original.

### Code signing the script

With the drive maps out of the way, the script is now stable code that rarely changes, which makes it a good candidate for signing.

It doesn't matter too much where the signing certificate comes from. What does matter is that the public key of the certificate (and its chain) is present in the right certificate stores on the endpoint, otherwise the signature won't be trusted and the script will be constrained. In practice that is:

- **Trusted Publishers**: so the signer is trusted to run scripts
- **Trusted Root Certification Authorities** (and Intermediate where applicable): so the chain validates

For this example I'm using the Azure public service, [Azure Artifact Signing](https://learn.microsoft.com/en-us/azure/artifact-signing/) (formerly Trusted Signing), where there is no private key to protect and certificates are short lived and rotated for you. An internal CA, a commercial certificate or even a self-signed certificate in a lab will all work the same way as long as the public key is deployed. I'm assuming you already have a signing account and certificate profile available.

<!-- IMAGE PLACEHOLDER: Azure Artifact Signing account and certificate profile in the Azure portal -->

Sign the script using the signing tooling, for example in a GitHub Actions workflow or from a workstation:

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

<!-- IMAGE PLACEHOLDER: Get-AuthenticodeSignature output showing Status Valid for DriveMapping.ps1 -->

#### Getting the certificate onto the device

The public key needs deploying to the endpoints. Export the signing certificate as a `.cer` file (public key only!) and add it to your existing Intune **Trusted certificate** profile, with the destination store set to **Computer certificate store - Root** (or **Intermediate** for an intermediate CA). Assign it to the same Autopilot group as the installer.

<!-- IMAGE PLACEHOLDER: Intune Trusted certificate profile with the .cer file and destination store -->

Trusted certificate profiles can't target the Trusted Publishers store, so if you need the certificate there, push it with a custom OMA-URI profile or a remediation script. If you are allowing the signer through a policy rule as described next, this isn't required.

### Allowing the signer in AppLocker or WDAC

The next piece is telling the endpoint to trust scripts signed by our certificate. Rather than allowing paths or hashes (which would need changing every time the script is updated), add a signing rule to your existing policy.

**WDAC**: add a signer rule for the certificate to your policy. If you are using the WDAC Wizard, add a custom rule of type **Publisher**, choose the certificate and select the level that matches your certificate profile. Scripts signed by an allowed signer are permitted to run in full language mode.

<!-- IMAGE PLACEHOLDER: WDAC Wizard custom rule, Publisher rule for the signing certificate -->

Test in audit mode first and check the `Microsoft-Windows-CodeIntegrity/Operational` event log for events 3076 and 3077 before enforcing.

**AppLocker**: under **Script Rules** add an **Allow** rule with the **Publisher** condition, point it at the signed script and set the slider to the level of the publisher you want to trust. PowerShell runs scripts allowed by an AppLocker rule in full language mode.

<!-- IMAGE PLACEHOLDER: AppLocker Script Rules showing the publisher Allow rule for the signing certificate -->

### The installer script

The final change is to the Intune script. The original created a scheduled task that downloaded the script and ran it with `Invoke-Expression`. That will never be trusted under WDAC, as a string passed into `Invoke-Expression` has no signature to validate.

The updated installer instead carries the signed script inside itself as a **base64 encoded byte array**. This matters: if the signed script were embedded as plain text, line endings, encoding and BOM changes would alter the bytes and break the signature. Encoding the raw bytes means the file that lands on disk is byte for byte what came out of the signing process.

Once the script has been signed, generate the encoded string:

```powershell
[Convert]::ToBase64String([System.IO.File]::ReadAllBytes(".\DriveMapping.ps1"))
```

and paste the result into `$encodedScript` in the installer. Every time you re-sign the script you need to regenerate this value and redeploy the installer.

The installer will then:

- Write the bytes to `C:\ProgramData\DriveMapping\DriveMapping.ps1`
- Check the Authenticode signature is valid before going any further
- Create the scheduled task at logon (or recreate it if the arguments change) that runs the file with `-File` and the `AllSigned` execution policy so an unsigned or tampered copy is refused

```powershell
<#
    DESCRIPTION:    Write a signed drive mapping script to disk from an embedded byte array and
                    create a Scheduled Task to run it at user logon
    AUTHOR:         Matt White
    DATE:           2026-11-22
    USAGE:          Paste the base64 string of the signed DriveMapping.ps1 into $encodedScript
                    and deploy as a system context script
#>

$scriptName = ([System.IO.Path]::GetFileNameWithoutExtension($(Split-Path $script:MyInvocation.MyCommand.Path -Leaf)))
$logFile = "$env:ProgramData\Intune-PowerShell-Logs\$scriptName-" + $(Get-Date).ToFileTimeUtc() + ".log"
Start-Transcript -Path $LogFile -Append

$installPath = "$env:ProgramData\DriveMapping"
$scriptPath  = Join-Path $installPath "DriveMapping.ps1"
$taskName    = "Map Network Drives"
$encodedScript = "<base64 of the signed DriveMapping.ps1>"

# Write the exact bytes so the signature stays valid
New-Item -Path $installPath -ItemType Directory -Force | Out-Null
[System.IO.File]::WriteAllBytes($scriptPath, [Convert]::FromBase64String($encodedScript))

$signature = Get-AuthenticodeSignature -FilePath $scriptPath
if ($signature.Status -ne 'Valid') {
    Remove-Item -Path $scriptPath -Force
    Stop-Transcript
    throw "Signature on $scriptPath is $($signature.Status), aborting"
}

$schedTaskArgs = "-ExecutionPolicy AllSigned -WindowStyle Hidden -File `"$scriptPath`""
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

Upload this to Intune in the same way as the original script and assign it to your Autopilot group. The installer itself runs as SYSTEM through the Intune Management Extension, so make sure your policy allows the Intune Management Extension scripts to run.

<!-- IMAGE PLACEHOLDER: Intune script assignment to the Autopilot device group -->

## The end result

When a user signs in, the scheduled task runs the signed script from `ProgramData`. The script checks the domain is reachable, gets tokens through WAM (silently on an Entra joined device), reads the drive maps JSON from the storage account using the user's own identity, works through every page of their group membership from Graph, then maps the drives that match.

If you check the language mode in the transcript you will see it is `FullLanguage` even with AppLocker or WDAC enforced, and a user who isn't in the storage role group simply gets no drives rather than a failed script.

Changing a drive map is now an upload of a new `drivemaps.json`. No code change, no re-signing, and no redeploy to the endpoints. Only changes to the script logic need a new signature and a refreshed installer.

<!-- IMAGE PLACEHOLDER: Mapped drives in File Explorer on a device with WDAC enforced -->

## The scripts in full

### Drive Mapping Script

<!-- TODO (Matt): paste the final tested DriveMapping.ps1 here, using the functions above and the unchanged DNS check and New-PSDrive loop from the original post -->

### Drive maps JSON

See the example earlier in this post.

### Installer Script

See the script earlier in this post.

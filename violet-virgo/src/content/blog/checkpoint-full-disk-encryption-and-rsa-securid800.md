---
title: "CheckPoint Full Disk Encryption and RSA SecurID800"
pubDate: "2011-07-07"
categories:
  - "it"
tags:
  - "certificates"
  - "check-point"
  - "full-disk-encryption"
  - "rsa"
  - "securid"
  - "sid800"
heroImage: "/blog-data-backup.png"
description: "Historical observations when dealing with CheckPoint Full Disk Encryption product and RSA SecurID tokens"
---

I have spent the past week looking at a peculiar issue with CheckPoint Full Disk Encryption for a client. As a bit of a background all laptops are encrypted with Full Disk Encryption and to provide two factor authentication we are using the RSA SecurID800 which acts as a Smart Card as well as a one time authenticator.

Whilst provisioning a laptop for a new starter we re-used an existing token, issued the Smart Card certificate from our internal Certification Authority and it was added to the token successfully. After updating Full Disk Encryption from the MI Console we rebooted and tested login. Everything worked fine.

The issues came when we removed the old certificates from the token and suddenly Full Disk Encryption was showing "Invalid Logon - No certificates were found on this token" yet when in Windows the RSA software shows the certificate is there and the fingerprint matches what was picked up from Active Directory by the MI Console. Rebooted the laptop and still the same no certificates error.

Speaking with CheckPoint on the issue didn't turn up much so I decided to issue a new certificate and try again. Went through the same process and upon reboot it worked fine and I put the original error down to a glitch so went and removed the old token from the SID800. Rebooted and it was broken again with the same error message.

To fix the issue I removed \*all\* certificates from the token, revoked all the issued ones in the CA and then issued one more for the user. All works fine and the user can now work on the laptop without issue.

Moral of the story... **Remove all certificates first and then only add the one that you need. Its easier in the long run**

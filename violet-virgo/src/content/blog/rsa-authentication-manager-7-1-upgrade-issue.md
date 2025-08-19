---
title: "RSA Authentication Manager 7.1 upgrade issue"
pubDate: "2011-08-31"
categories:
  - "it"
tags:
  - "password"
  - "rsa"
heroImage: "/blog-data-backup.png"
description: "Technote that describes how to recover RSA Authentication Manager during an upgrade if the password is changed"
---

Following on from my [article](http://www.matthewjwhite.co.uk/blog/2011/07/18/sa-authentication-manager-sql-bug/ "RSA Authentication Manager SQL bug") on the SQL files bug in RSA Authentication Manager 7.1 we were looking to carry out the upgrade to the client's server in a maintenance window last weekend however the engineer carrying out the work was unable to login to the Operations Manager console to carry out certain parts of the upgrade task.

It turns out that since RSA was installed the Security Console Super Admin account had its password changed and in the updated documentation we lost the details of the password for the Operations Console as the two passwords are not linked. In order for us to get back into the Operations Console we had to run through the following:

1. Create a new Super Admin from the Security Console in the Internal Database
2. Run the RSA command line utility (C:Program FilesRSA SecurityRSA Authentication ManagerutilsRSAutil) to create a new Operations Console user account

Unfortunately it wasnt that easy to complete!

Initially when we ran RSAutil as one of the admin accounts we received an error stating that only one account could run it, the account that originally installed RSA! Luckily the account was still listed and we just needed to enable this and perform a swift "runas" to bring up a command prompt as that user.

Next we sent a good bit of time running through various commands to work out how we create a new Operations Console admin account. The final command that we needed to run was as follows:

```cmd
rsautil manage-oc-administrators -a create -u _UserCreatedEarlier_ -p _PasswordForUserCreatedEarlier_ -g OperationsConsole-Administrators _NewOperationsConsoleUsername NewOperationsConsolePassword_
```

We were now able to login to the Operations Console using the account we created. Now to find another maintenance window to patch the RSA server

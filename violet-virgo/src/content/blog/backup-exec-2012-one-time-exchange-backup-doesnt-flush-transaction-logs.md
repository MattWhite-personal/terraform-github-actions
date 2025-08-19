---
title: "Backup Exec 2012 - One time Exchange Backup doesnt flush transaction logs"
pubDate: "2012-06-07"
categories:
  - "backups"
  - "it"
tags:
  - "backup-exec"
  - "exchange-2010"
  - "symantec"
heroImage: "/blog-data-backup.png"
description: "Short technote that looks at how Symantec Backup Exec handles one time backup jobs for Exchange Server"
---

I have spent the last few days trying to understand why a successful one time backup hadn't flushed the transaction logs on my client's Exchange 2010 server. We spent a lot of time troubleshooting message queues and looking for a transaction that hadn't completed as the Backup job had reported successful. Digging a bit deeper into some of the job logs I can see that the one-time backup was doing a COPY - Full database and logs and not a FULL - database and flush committed logs.

Googling this came up with the following technote: [http://www.symantec.com/business/support/index?page=content&id=TECH187838](http://www.symantec.com/business/support/index?page=content&id=TECH187838 "In Backup Exec 2012, One-time backup job for Exchange does not flush the transaction logs") and there is no way that you can change the option to do a full log flush in the one time backup.

I can't fathom why this wouldn't be a useful feature of the software to at least have the flush committed logs as a tickbox in the job options for the one-time backup.

![](/images/bue2012-logs.jpg "Backup Exec 2012 Exchange Backup")

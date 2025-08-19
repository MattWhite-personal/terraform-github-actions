---
title: "Backup Exec 12.5 DFS File Restores"
pubDate: "2009-10-16"
categories:
  - "backups"
  - "it"
tags:
  - "backup"
  - "backup-exec"
  - "dfs"
  - "microsoft"
  - "replication"
  - "restore"
  - "symantec"
heroImage: "/blog-data-backup.png"
description: "The blog post provides an overview for how data restore from DFSr replicated folders using Volume Shadow Copy. It is based on an obsolete version of Symantec BackupExec 12.5"
---

I thought that this deserves a special mention.

Backup Exec backs up the DFSr Replicated Folders using the shadow copy components and in the past to perform a restore you were unable to redirect the files to an alternate location. This could cause issues if you wanted to keep both versions of the file as Backup Exec would overwrite the file and then perform an inital replication of that DFSr folder to the other servers in its replication group.

Whilst you could also perform an Authoritative restore of the DFSr folder this has recently caused me even more issues which resulted in support calls to Symantec and Microsoft to follow up on why this happens and what state my DFS is now in as a result of these restores.

During the inital support call to Symantec they advised me that for the first time in Backup Exec you can redirect the files you restore from the Volume Shadow Copy of the DFSr folders. Simply select the server and location in the File Redirection tab in Backup Exec and you will be able to dump the folder structure to whereever you want it and then copy the relevant files back into your DFS structure as you want it.

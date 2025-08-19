---
title: "Symantec Endpoint Protection Manager 12.1 configuration"
pubDate: "2012-06-13"
categories:
  - "it"
tags:
  - "antivirus"
  - "endpoint-protection"
  - "symantec"
heroImage: "/blog-monitoring-header.png"
description: "Technote that describes issues with Symantec Endpoint Protection Manager not protecting the SQL database instance and clearing out historical transaction logs and data."
---

Just stated to deploy my first SEP 12.1 implementation for a new client and came across a bug whereby the disk space on the system drive where SEPM had been installed was decreasing rapidly.  Investigation showed that the Endpoint Protection Manager is not configured by default to backup or truncate the log files for its database.

For more information from Symantec on the configuration of the truncate and index rebuild options please review the following KB article: [http://www.symantec.com/business/support/index?page=content&id=TECH166658](http://www.symantec.com/business/support/index?page=content&id=TECH166658)

One other thing that was pointed out by a colleague was that Backup Exec is unable to backup the Database files and you will need to configure SEPM to backup and export the data if you would like to recover the current SEPM configuration in the event of having to restore the server from backup.

To fix this is straightforward but led me to ask the question why Symantec wouldn't think this needs to be enabled by default for the product.

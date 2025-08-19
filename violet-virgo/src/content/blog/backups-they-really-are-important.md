---
title: "Backups - They really are important"
pubDate: "2009-06-14"
categories:
  - "backups"
  - "it"
tags:
  - "backup"
  - "disaster-recovery"
  - "dr"
  - "server"
  - "tape"
heroImage: "/blog-data-backup.png"
description: "The blog post provides an opion on the requirement to protect IT business data. It was written working for a previous IT firm and whilst the technologies have moved on the sentiment about protecting data and services is still relevant"
---

# Introduction

You really cannot appreciate the need for a solid backup solution until you need to restore that crucial piece of business critical data. Whether it's a whole server or just one word document it is always important to know that the files are available to be recovered. There is no single solution that works in all scenarios and it is important to select the technologies that meet the needs of the individual site. This article will look at a number of different technologies and try to demonstrate how they can be used in a business environment and help negate the need to use companies like [Kroll Ontrack](http://www.ontrackdatarecovery.co.uk) to perform data recovery on hard drives which can be incredibly costly.

# Shadow Copy / Previous Version Client

"Shadow Copies for Shared Folders is a new file-storage technology in the Microsoft Windows Server 2003 operating systems. Shadow Copies for Shared Folders provides point-in-time copies of files that are located on a shared network resource, such as a file server. With Shadow Copies for Shared Folders, users can quickly recover deleted or changed files that are stored on the network without administrator assistance, which can increase productivity and reduce administrative costs." ([Shadow Copies for Shared Folders Technical Reference](http://technet.microsoft.com/en-us/library/cc758899.aspx))

This technology is the basis of the Previous Version client and allows recovery of accidently deleted files without having to request tapes or an online restore which may incur further delays in restoring the data. The snapshots are stored on your file server and you should make sure that you have sufficient space to store all your data as well as shadow copies. So that you don't run out of space on the server a maximum size for the shadow copies is defined and at each snapshot the server will calculate if it can store the next snapshot in the data store without deleting older versions. When it can no longer store new snapshots Shadow Copy will delete the oldest snapshots to make way for the newest changes.

As mentioned this is a nice technology to quickly recover a few files or folders but should NOT be considered a backup solution on its own as you are reliant on your server always being online and having sufficient space to store enough copies of the data that you can restore what you need to. Shadow copy does not allow for hardware failure and should your disk array fail in the server you will lose the data as well as the previous version snapshots.

# Tape Backup

Tape backups have been around almost as long as computers have and writing data to a magnetic tape is a tried and tested way of keeping a copy of the data that can be taken off-site to cover the loss of a server. Today backup tapes are able to store up to 1.6TB of data (depending on tape model and compression) on a single cartridge. As a result the tape backup is still widely used today as the backup solution of choice in the workplace as after the initial expenditure of buying the tape drive and software to backup your infrastructure there is little ongoing expense involved in maintaining the tape based backup solution.

The key thing to remember when using a tape based backups is to NOT keep your backup tapes in the same building as the server that you are backing up. You can backup all your data and keep a full year of backups but if they are sitting next to your server and there is a fire you lose both the server and the tapes and are unable to restore the data. It is recommended that once data has been written to tape that the user responsible for changing the tapes removes the tape to a secure location. There are companies, such as [Iron Mountain](http://www.ironmountain.co.uk/dataprotection/vault), who offer services to collect tapes on a regular basis and store them in a secure vault. This can give you the peace of mind that you only have the minimum number of tapes on site at any one time.

The number of different backups you keep is completely dependent on how far back you feel you need to recover data. One tape that is overwritten daily is not a safe solution and while it is possible to use a completely new tape for each backup this can quickly become a costly way of backing up data. The most common backup hierarchy is the Grandfather, Father, Son scenario. In this scenario your Son backup would usually be your daily backup and then at the end of each week the Friday/Weekend backup is kept as the Father and at the start of the new week a new set of Son backups is created. At the end of the month the last Father backup is promoted to Grandfather and the process starts again at the beginning of the new month. It is recommended that the Grandfather backups be kept for a set as a reference of the data at that point in time. Over the course of a year using this technology you will need to have 21 tapes to rotate through. (4 tapes for Monday - Thursday, 5 tapes for the Friday/Weekend backups and 12 month end tapes). If you would like to keep two weeks of daily backups you will need a further 4 tapes to cover the second week.

# Online Backup

If you have data based across multiple sites or you don't want to be forced to change tapes on a nightly basis an online backup solution may prove to be a viable solution. In the same way as the tape backup will capture your data on a nightly basis and write it to a magnetic tape the software here will connect to a 3rd party data server and upload the data to be stored here.

Rather than taking a full backup of all the files each night the online backup solutions usually look at taking an initial base backup on site which is integrated into the off-site storage platform and then each night an incremental backup will copy changes since the previous backup to the platform. As a result of this files are stored based on the number of impressions that are pushed to the backup platform i.e. a file can be backed up on day 1 but doesn't change for 2 months at which point the second impression is saved to the backup platform whereas a file that changes daily will write a new impression each time that file is backed up. The number of impressions you want to keep is dependent on the money you are willing to pay for storage.

When planning for an online backup it is important to work out how much data will be changing on a daily basis and needs to be sent across the Internet to the storage platform. If your Internet connection doesn't have sufficient bandwidth you will not be able to take a full snapshot each night and could end up with gaps in your backups that prevent complete restoration of all the data.

# Disaster Recovery Site

If the nature of your business means you cannot afford to be offline whilst your IT infrastructure is restored then a DR site may be something worth considering. If your Infrastructure is severely crippled then you are able to switch core services to another site and your users are able to continue working with minimal disruption.

Microsoft developed the DFS Replication technology in Server 2003 to enable file shares to be replicated between multiple servers in real time. In the case of your primary file server failing you simply need to switch your referral server to your DR site and users will be able to access data through the same file shares and shouldn't notice the changeover. Replication of databases such as Microsoft Exchange or SQL is not as easy to replicate in the same way as the database files are constantly changing with each access. In these cases 3rd party applications such as [DoubleTake](http://www.doubletake.com) or [XOSoft](http://www.ca.com/us/products/product.aspx?id=8232) (formerly WANSync) can be used to make sure that your databases are replicated in real time to the DR site so they can be switched over as needed. With these scenarios users are able to keep working whilst the core infrastructure is recovered and then any changes made whilst working in the Disaster Recovery scenario can be replicated back to the main offices.

The Disaster Recovery solution is not a cheap solution as you need to pay for a second set of servers to replicate the data to and run in an alternate site such as a data centre however the running costs need to be compared with the cost to the company whilst services are restored.

# What should YOU do?

What you do now is a very individual decision based around the needs of your business. There are companies that implement all four different technologies mentioned to provide resilience against there being an issue with any of the other backups however this is a costly solution that is not viable for a number of small companies. For most, implementing either the tape or the online backup along with the Shadow Copy snapshots will provide enough security to restore the data should files be deleted or a server fail.

It should be noted however that the backup to tape or offsite should never be taken for granted and ignored. As part of any backup strategy you should be looking to run test restores from your backup media to ensure that you can recover the data you have backed up.

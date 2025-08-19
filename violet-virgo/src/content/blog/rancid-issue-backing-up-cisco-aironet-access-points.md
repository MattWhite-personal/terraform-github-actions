---
title: "RANCID: Issue backing up Cisco Aironet access points"
pubDate: "2011-10-18"
categories:
  - "it"
tags:
  - "access-point"
  - "backup"
  - "cisco"
  - "config"
  - "rancid"
  - "wireless"
heroImage: "/blog-monitoring-header.png"
description: "How to resolve backup of legacy Cisco Aironet devices using RANCID"
---

I have had [RANCID](http://www.shrubbery.net/rancid/) setup to backup switch and firewall config for a while now but not I had always had issues with backups of my Cisco access points which I had thought was an issue with the version of RANCID or the slight differences in IOS run on the WAPs versus the Switches. Turns out after revisiting it yesterday it was more a [PEBKAC](http://en.wikipedia.org/wiki/User_error#PEBKAC) or [ID-10-T](http://en.wikipedia.org/wiki/User_error#ID-10-T_Error) error on my part!

What I had in my .cloginrc file was:

```
add user ip_address {username}
add password ip_address {password}
add method ip_address {ssh}
add noenable ip_address 1
```

when I ran bin/clogin ip_address the device would login and get me to the enable prompt as expected but when run as part of rancid_run nothing was coming back for the config. After a bit of reading and searching the solution was simple enough and it wasnt a problem with RANCID or the Aironets....

```
add autoenable ip_address 1
```

should have been used instead of the noenable line.

I also managed to get RANCID to backup the config on my Juniper EX switches but that is a story for another post

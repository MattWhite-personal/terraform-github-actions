---
title: "RANCID: Backing up Juniper EX switches"
pubDate: "2011-10-18"
categories:
  - "it"
tags:
  - "backup"
  - "juniper"
  - "rancid"
  - "switch"
heroImage: "/blog-monitoring-header.png"
description: "how to use RANCID to create backups of Juniper EX switches based upon configuration changes"
---

As part of my drive to backup all my switch/firewall configs I have been trying to get [RANCID](http://www.shrubbery.net/rancid/) to backup the remaining devices on my network. The latest devices we added to the network were a pair of [Juniper EX](http://www.juniper.net/us/en/products-services/switching/ex-series/) switches that are part of an iSCSI network and until now I have not had a backup of the configs. Looking at the documentation there is a set of commands to backup other JunOS devices so thought I would give it a go.

RANCID is running on an [Ubuntu 10.04 server](http://www.ubuntu.com) and is running version 2.3.3. and has the jlogin scripts in place. After adding the device information to the .cloginrc file I tested jlogin to check that it could connect as root to the device - it did. When I performed rancid_run however the device did not backup as expected and Rancid hung until it timed out. Upon closer inspection the issue came down to the fact that the root account will ssh to the BSD shell on the switch and not directly to the JunOS command line. To get around this I needed to setup a new user on the switches with the correct permissions and then get this to perform the backup of the switches. The command to add the config is as follows:

```
set system login user adminusername class super-user authentication plain-text-password
```

You will be prompted to choose a password and then confirm it before writing it to configuration

```
commit and-quit
```

Now you can specify the details in RANCID:

```
add user ip_address {username}
add password ip_address {password}
add method ip_address {ssh}
```

The last thing that I did was to take a copy of jlogin and jrancid from an installation of RANCID 2.3.6 and everything seems to be working as expected.

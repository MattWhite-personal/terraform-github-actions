---
title: "check_equallogic volumes bug"
pubDate: "2011-10-12"
categories:
  - "it"
  - "monitoring"
tags:
  - "dell"
  - "equallogic"
  - "nagios"
  - "opsview"
  - "plugin"
  - "snmp"
heroImage: "/blog-monitoring-header.png"
description: "Technote that demonstrates how to monitor Dell Equallogic storage arrays over SNMP and how to feed that data into a monitoring product such as Nagios or Opsview"
---

I have been playing arond with the [check_equallogic](http://www.claudiokuenzler.com/nagios-plugins/check_equallogic.php) Nagios plugin written by Claudio Kuenzler ([http://www.claudiokuenzler.com](http://www.claudiokuenzler.com)) to monitor some performance and utilisation values for a client and I came across a bug with the code in the latest release which I thought I would share.

The latest release allows you to monitor the size of a single volume as well as a single check to monitor all volumes. I setup the check in Opsview as normal and then proceeded to configure the Host Attributes for the SAN host for each volume on the SAN (there were 75 volumes to monitor). Having added all the checks and reloading Opsview I started to see a large number of OK checks for the volumes but also a number of UNKNOWN outputs from the plugin. Closer inspection showed that when you have two volumes that have the similar names (e.g. BES01-D and DR-BES01-D) the more generic name, BES01-D in this example will match for both volumes and the script will return an unknown value. The DR-BES01-D volume returned the correct stats as the volume name only matched one entry.

Looking through the code in the plugin the line that is causing the issue is:

```
volarray=$(snmpwalk -v 2c -c ${community} ${host} 1.3.6.1.4.1.12740.5.1.7.1.1.4 | grep -n ${volume} | cut -d : -f1)
```

When it grep's the list of volumes from the SNMP walk it returns two values and the script cannot cope so exits. After some playing around (and remembering the basics of writing bash scripts) I managed to work around the problem and changed the line to the following:

```
volarray=$(eval snmpwalk -v 2c -c ${community} ${host} 1.3.6.1.4.1.12740.5.1.7.1.1.4 | grep -n ""${volume}"" | cut -d : -f1)
```

The change adds the quotation marks that are surrounding the string value that is returned from the SNMPwalk so GREP should only return the exact matches. Having updated the script and re-run the checks the UNKNOWN status was gone and the checks all returned the correct data.

---
title: "Opsview - patch for check_route plugin"
pubDate: "2011-12-01"
categories:
  - "it"
  - "monitoring"
tags:
  - "monitoring"
  - "opsview"
  - "route"
  - "traceroute"
  - "tracert"
heroImage: "/blog-monitoring-header.png"
description: "Short technote that outlines a fix to the code of the Opsivew check_route plugin"
---

I was playing around with the check_route plugin and noticed a few issues with it not running. In order to get it to work on my Opsview boxes I had to install a new package, change some settings on the traceroute program and then make a patch in the script itself.

First thing you need to do is download the traceroute package if its not already installed

```bash
sudo apt-get install traceroute
```

Once installed you will find that the plugin will fail and show the following error:

```
The specified type of tracerouting is allowed for superuser only
Can't use an undefined value as an ARRAY reference at ./check_route line 129.
```

Googling the first line I found that you have to setuid root for the traceroute binary

```bash
chmod u+s /usr/sbin/traceroute
```

Trying the plugin again you get the following error

```
Use of uninitialized value $time_units in string eq at ./check_route line 114.
ROUTE UNKNOWN - Cannot cope with line 'traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets'
```

To get around this you need the plugin to ignore the first line of the output from the traceroute which can be done with the following patch

[http://snipt.net/mattywhi/opsview-check_route-diff/](http://snipt.net/mattywhi/opsview-check_route-diff/)

Now the script runs as expected and you get the following output

```
ROUTE OK - Time taken is 145.895 ms | total_time=145.895ms;5000;100000 hops=14;; route_change=0;;
```

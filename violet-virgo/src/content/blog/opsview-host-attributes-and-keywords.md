---
title: "Opsview: Host Attributes and Keywords"
pubDate: "2010-09-02"
categories:
  - "it"
  - "monitoring"
tags:
  - "abstraction"
  - "attributes"
  - "monitoring"
  - "nagios"
  - "opsview"
  - "snmp"
heroImage: "/blog-monitoring-header.png"
description: ""
---

Having been an avid Nagios/Opsview user for a while I am always keen to see new features that make my life of defining and managing systems easier. I had been meaning to try out the host attributes feature of Opsview for a while to redefine the way I monitor various "generic" features on my infrastructure. Up until now I have had to create an exception for a host that I want to monitor in a slightly different way and remembering what did/didnt have exceptions was never the easiest thing to do.

This has all changed with the Host Attributes feature in Opsview. I can now define a single service check that will take a number of values (currently Opsview 3.7.2 will only let you define one however looking at the SQL database there is capacity for 9 arguments. A forum post from Ton Voon has revealed a patch to the host-attributes tab that allows you to define 4 attributes which should be released in an upcoming release - 3.7.3 maybe). This means that I can define a host attribute (e.g. DISK) and then set in this the partition/disk name and the warning/critical values in different arguments to make sure that I can reduce the number of custom service checks or exceptions that I need to define.

I have managed to abstract my Disk space checks and also some checks for Exchange Information Store sizes across my organisation. I plan to try and further abstract other generalised items of monitoring (e.g. Windows Services, Performance counters etc).

Once I had created these checks I needed to add in a viewport to display the status of my Information Stores. In the past this used to be setup individually on each host and service check manually. In the latest release its possible to create a new keyword and then add in the host/services that you want from the Keywords tab. This has made the process of making new views/displays easier and made the monitoring much simpler.

When I get some time I will put up some pictures to go with this article and expand on my ability to monitor network interfaces with the latest version of Opsview.

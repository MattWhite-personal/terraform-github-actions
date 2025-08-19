---
title: "Rancid email notification issues"
pubDate: "2010-08-05"
categories:
  - "it"
tags:
  - "cisco"
  - "config"
  - "monitoring"
  - "rancid"
  - "routers"
  - "switches"
  - "wireless"
heroImage: "/blog-monitoring-header.png"
description: "Making changes to a Postfix deployment to integrate mail flow for RANCID notifications"
---

Just spent a few days getting RANCID setup on one of my monitoring servers to backup my device configs on a daily basis. Whilst setting it up I followed a number of guides to get my config files setup and checked. The one thing I couldnt get to work however was the email when RACID detected a config change on one of the network devices.

Scouring the Internet I couldnt find what I had missed. Postfix was setup correctly and I could use the aliases I setup in /etc/alises if i "telnet localhost 25" and mail was delivered. In the end looking at the update logs I could see a line saying it couldnt find sendmail.

A quick look at racnid_control and I updated the lines that referenced sendmail to include a full path to /usr/sbin/sendmail and low and behold my inbox was full of config changes this morning.

I'm sure that if I was able to get the money to buy Opsview Enterprise I would make full use of the RANCID module within this but for the moment this works well enough for me.

My next goal is to get SNMP Trap processing setup so that if the appropriate trap is received from a monitored device it will pull the latest config down and we will always have the latest config.

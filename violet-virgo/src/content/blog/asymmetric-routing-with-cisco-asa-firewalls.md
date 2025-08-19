---
title: "Asymmetric routing with Cisco ASA firewalls"
pubDate: "2012-02-13"
categories:
  - "networking"
tags:
  - "asa"
  - "cisco"
  - "routing"
  - "tcp-syn"
heroImage: "/blog-network-header.png"
description: "short technote that describes how to ensure that traffic routing across an ASA Series Cisco firewall is not routed asymetrically"
---

Last month I installed a new Cisco ASA 5510 for a client and came across an issue where traffic was hitting the "inside" interface of the firewall before travelling back out the same interface and into another router on the internal LAN - an issue as reported in this article [Cisco ASA Deny TCP (no connection)](http://blog.getcaffeinated.net/?p=10 "Cisco ASA Deny TCP (no connection)")

The diagram below demonstrates the network setup with PC1 trying to communicate with PC2. When the traffic leaves the MPLS router (RED line) it does not traverse the ASA and the next packet will follow the original route (GREEN then ORANGE lines) to get to PC2

![Representing the traffic flow](/images/Cisco_SYN.png "Cisco_SYN")

Long term the resolution is to place the extra routers into their own DMZ networks on the perimeter network but as this didn't exist at the time I needed to disable the TCP SYN checking for the traffic being routed to the MPLS routers - a process described in this article by Cisco - [Configuring TCP State Bypass](http://www.cisco.com/en/US/docs/security/asa/asa82/configuration/guide/conns_tcpstatebypass.html "Configuring TCP State Bypass")

First thing we do is create an ACL for all the items we want to bypass the SYN check

```
access-list firewall_bypass extended permit ip object Local_LAN object Remote_LAN_1
access-list firewall_bypass extended permit ip object Local_LAN object Remote_LAN_2
access-list firewall_bypass extended permit ip object Local_LAN object Remote_LAN_3
```

Now we create a class map to match the ACL

```
class-map class_firewall_bypass
match access-list firewall_bypass
```

Then apply this to a policy map

```
policy-map inside-policy
class class_firewall_bypass
set connection advanced-options tcp-state-bypass
```

Finally we assign that policy to the inside interface on the firewall

```
service-policy inside-policy interface inside
```

Traffic that hits the inside interface of the firewall that matches the rules on the ACL will not be checked for their tcp state and traffic should now flow.

In the long term it is recommended that this isnt the adopted approach and the firewall is configured to have the traffic traverse through from the inside to a DMZ interface to prevent the issues with the TCP SYN issue

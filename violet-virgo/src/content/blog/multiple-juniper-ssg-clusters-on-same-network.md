---
title: "Multiple Juniper SSG clusters on same network"
pubDate: "2011-06-08"
categories:
  - "it"
tags:
  - "arp"
  - "firewall"
  - "juniper"
  - "mac"
  - "packetloss"
  - "routing"
  - "ssg"
heroImage: "/blog-network-header.png"
description: "Historical technote that highlights an issue with Juniper ScreenOS clusters on the same network link. The issue is related to how the clusters generate the virtual MAC address"
---

I ran into an issue recently with a client where we were seeing a large level of packet loss to their newly installed SSG140 cluster. There were three clients sharing the same 100Mbit Internet circuit and they all connected directly into a pair of [Juniper SRX210](http://www.juniper.net/us/en/products-services/security/srx-series/) routers.

All three clients had a firewall cluster which was either made up of a pair of [Juniper SSG 140](http://www.juniper.net/us/en/products-services/security/ssg-series/ssg140/)s or [Juniper SSG 5](http://www.juniper.net/us/en/products-services/security/ssg-series/ssg5/)s and we were seeing the packet loss on the two SSG 140 clusters.

After some investigation and troubleshooting the following KB article from the Juniper website seemed to demonstrate what the problem was: [http://kb.juniper.net/InfoCenter/index?page=content&id=KB7435](http://kb.juniper.net/InfoCenter/index?page=content&id=KB7435)

The virtual MAC address for both firewall clusters public facing interfaces were the same.

Resolution? Rebuild one of the clusters to use a different cluster ID and the MAC address generated for the firewalls is different.

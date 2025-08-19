---
title: "Configuring Juniper SSG Firewalls to failover between Internet connections"
pubDate: "2011-11-07"
categories:
  - "it"
tags:
  - "failover"
  - "firewall"
  - "internet"
  - "juniper"
  - "ssg"
heroImage: "/blog-network-header.png"
description: "The blog post provides a detailed guide on setting up failover for Juniper SSG firewalls. It explains how to configure the firewall to use track-IP for monitoring IP addresses and automatically switch between primary and secondary internet connections in case of failure. The post covers the steps to move interfaces into separate virtual routers, set up default routes, and ensure internal users can route through both connections. This setup helps maintain internet connectivity and enhances network reliability"
---

I have been working with the Netscreen, and then Juniper firewall products for the past five years and am still learning new and interesting features they offer. One thing that I have been configuring more and more recently are secondary Internet connections and fail-over between them for clients. This post runs through the steps required to configure an SSG firewall to use track-IP to monitor IP addresses on the Internet and then automatically fail-over and fail-back an Internet connection.

The first thing we need to do is move the interfaces that will contain the Internet connections so each is in their own virtual router. This will allow us to have an active default route for each connection and they can behave independently of each other.

```
set interface ethernet0/0 zone null
set interface ethernet0/1 zone null
set zone untrust vrouter untrust-vr
set vrouter name adsl-vr
set zone name BackupUntrust
set zone BackupUntrust vrouter adsl-vr
set interface ethernet0/0 zone Untrust
set interface ethernet0/1 zone BackupUntrust
```

For this example I am using the 192.0.2.0/24 address range for my WAN connections - this was defined by the IETF as a subnet to be used for testing and documentation in [RFC 5735](http://tools.ietf.org/html/rfc5735). As these interfaces are both public facing I am also going to restrict the management to secure protocols only

```
set interface ethernet0/0 ip 192.0.2.2/29
set interface ethernet0/0 route
set interface ethernet0/0 manage-ip 192.0.2.3
set interface ethernet0/0 manage ping
set interface ethernet0/0 manage ssh
set interface ethernet0/0 manage ssl
set interface ethernet0/1 ip 192.0.2.10/29
set interface ethernet0/1 route
set interface ethernet0/1 manage-ip 192.0.2.11
set interface ethernet0/1 manage ping
set interface ethernet0/1 manage ssh
set interface ethernet0/1 manage ssl
```

Now we need to setup the default routes out of each virtual router so that each connection can communicate with the rest of the Internet

```
set vrouter untrust-vr
set route 0.0.0.0/0 interface ethernet0/0 gateway 192.0.2.1
exit
set vrouter adsl-vr
set route 0.0.0.0/0 interface ethernet0/1 gateway 192.0.2.9
exit
```

We need to ensure that our internal users are able to route to both the untrust-vr and adsl-vr. This can be done by exporting the default static route from the untrust-vr and adsl-vr

```
set vrouter "untrust-vr"
set access-list 1
set access-list 1 permit ip 0.0.0.0/0 1
set route-map name "untrust-vr_export" permit 1
set match ip 1
set preserve preference
exit
set export-to vrouter "trust-vr" route-map "untrust-vr_export" protocol static
set vrouter "adsl-vr"
set access-list 1
set access-list 1 permit ip 0.0.0.0/0 1
set route-map name "adsl-vr_export" permit 1
set match ip 1
exit
set export-to vrouter "trust-vr" route-map "adsl-vr_export" protocol static
```

This will import both default routes to the trust-vr and set maintain the preference of the export from the untrust-vr at 20 whilst setting the metric of the adsl-vr export to 140.

Now that our users can connect to the Internet we need to make sure that should there be an issue with the primary internet circuit the backup circuit can be used for Internet access. This is achieved by using track-ip to monitor a number of hosts on the Internet and should they become unreachable shut the interface down.

In this example we are using the IP address of some of the root DNS servers as the addresses the firewall will use to check for a valid Internet connection but they could be any IP addresses that you expect to remain online and will respond to PING requests

```
set interface ethernet0/0 threshold 75
set interface ethernet0/0 monitor track-ip ip
set interface ethernet0/0 monitor track-ip threshold 75
set interface ethernet0/0 monitor track-ip weight 75
set interface ethernet0/0 monitor track-ip ip 192.58.128.30 threshold 25
set interface ethernet0/0 monitor track-ip ip 192.58.128.30 weight 25
set interface ethernet0/0 monitor track-ip ip 192.36.148.17 threshold 25
set interface ethernet0/0 monitor track-ip ip 192.36.148.17 weight 25
set interface ethernet0/0 monitor track-ip ip 193.0.14.129 threshold 25
set interface ethernet0/0 monitor track-ip ip 193.0.14.129 weight 25
```

This will PING the three addresses every second and will consider the address to have failed when the test has failed 25 times consecutively. Summing these three failures together will hit the weight and threshold limits of 75 needed to shut down the interface.

> UPDATE: Since this was written Juniper released newer firmware that allowed you to specify the interface threshold for failure in addition to the Track-IP threshold. This would mean that track-ip would fail at 75 but the interface default was set to 255 for failover, the config above has been amended accordingly to reflect this change in behaviour.

If you want to test the status of the track-ip monitoring you can issue the following commands

```
get interface ethernet0/0 monitor
get interface ethernet0/0 monitor track-ip
```

and you will be able to see the failure statistics as well as whether the interface is failed or not.

When the interface is shut down the default route no longer becomes valid in the untrust-vr and will be deleted in the trust-vr leaving the export from the adsl-vr active and Internet traffic will continue to function as normal. In the background, the management address on the primary connection will continue to poll the IP addresses configured and when they become available the weight and threshold will be below the failure values, the interface comes back up and the untrust-vr route export re-appaers in the trust-vr.

The only other thing to consider here is inbound services on the backup line such as MX records to permit mail delivery to a MIP or VIP on the secondary circuit

If this is all configured correctly the only things the user should notice is that any websites/services that login and use session data (eg online banking) will need to login after fail-over or fail-back as their existing session will no longer be valid.

The only remaining task is to commit the changes you have made to flash

```
save
```

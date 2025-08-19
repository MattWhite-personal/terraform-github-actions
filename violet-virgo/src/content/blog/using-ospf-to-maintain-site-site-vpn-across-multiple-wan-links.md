---
title: "Using OSPF to maintain site-site VPN across multiple WAN links"
pubDate: "2014-12-29"
categories:
  - "it"
  - "networking"
tags:
  - "juniper"
  - "ospf"
  - "screenos"
  - "vpn"
heroImage: "/blog-network-header.png"
description: "Technote that describes how to use OSPF network protocol to deliver resilience across site to site vpn links on Juniper ScreenOS firewall appliances"
---

Having a Single Point of Failure (SPoF) on your network is never a desirable situation and recently I implemented a multi-site set-up where each site had two internet connections and there was a requirement to enable the satellite office to connect to the head office at all times. Each site has a Juniper SSG5-SB firewall as well as a 10Mbit leased line primary Internet circuit and an ADSL backup.

With the Juniper SSG firewalls it is possible to use Policy Based VPNs to maintain multiple tunnels and have the firewalls switch between these as required however you end up with four policies on each firewall and you cannot tell from looking at a routing table where the traffic is flowing. In this instance I decided to make use of OSPF to dynamically route the traffic depending on the availability of the VPNs at each site.

The first thing we need to do in order to implement this is to put each Internet connection into its own Virtual Router so they can run independently of each other.I have covered this in a recent blog post which you can [read here](/2011/11/07/configuring-juniper-ssg-firewalls-to-failover-between-internet-connections/ "Configuring Juniper SSG Firewalls to failover between Internet connections").

Once you have the two firewalls setup with each Internet connection in its own virtual router we need to setup the VPNs. This is done with a new Zone in the trust-vr and we will need four numbered tunnel interfaces on each firewall.

```
set zone name VPNZone
set zone VPNZone vrouter trust-vr
set interface "tunnel.1" zone "VPNZone"
set interface "tunnel.2" zone "VPNZone"
set interface "tunnel.3" zone "VPNZone"
set interface "tunnel.4" zone "VPNZone"
set interface tunnel.1 ip 172.16.1.1/30
set interface tunnel.2 ip 172.16.1.5/30
set interface tunnel.3 ip 172.16.1.9/30
set interface tunnel.4 ip 172.16.1.13/30
```

On the second site firewall you will need to repeat the commands but using the other IP address in the /30 in each case.

Now we need to setup the VPN tunnels. You may want to change these based upon your requirements however I have used these settings regularly and they work well. NB you will need to apply similar settings on the Site-B firewall with the various endpoint addresses for SiteA

```
set ike gateway "Site-A_PRI-Site-B_PRI" address 192.0.2.18 Main outgoing-interface "ethernet0/0" preshare EnterYourPSKHere proposal "pre-g2-aes128-sha"
set ike gateway "Site-A_PRI-Site-B_SEC" address 192.0.2.34 Main outgoing-interface "ethernet0/0" preshare EnterYourPSKHere proposal "pre-g2-aes128-sha"
set ike gateway "Site-A_SEC-Site-B_PRI" address 192.0.2.18 Main outgoing-interface "ethernet0/1" preshare EnterYourPSKHere proposal "pre-g2-aes128-sha"
set ike gateway "Site-A_SEC-Site-B_SEC" address 192.0.2.34 Main outgoing-interface "ethernet0/1" preshare EnterYourPSKHere proposal "pre-g2-aes128-sha"
set vpn "Site-A_PRI-Site-B_PRI IKE" gateway "Site-A_PRI-Site-B_PRI" no-replay tunnel idletime 0 proposal "g2-esp-aes128-sha"
set vpn "Site-A_PRI-Site-B_PRI IKE" monitor optimized rekey
set vpn "Site-A_PRI-Site-B_PRI IKE" id 0x6 bind interface tunnel.1
set vpn "Site-A_SEC-Site-B_PRI IKE" gateway "Site-A_SEC-Site-B_PRI" no-replay tunnel idletime 0 proposal "g2-esp-aes128-sha"
set vpn "Site-A_SEC-Site-B_PRI IKE" monitor optimized rekey
set vpn "Site-A_SEC-Site-B_PRI IKE" id 0x3 bind interface tunnel.2
set vpn "Site-A_SEC-Site-B_PRI IKE" dscp-mark 0
set vpn "Site-A_PRI-Site-B_SEC IKE" gateway "Site-A_PRI-Site-B_SEC" no-replay tunnel idletime 0 proposal "g2-esp-aes128-sha"
set vpn "Site-A_PRI-Site-B_SEC IKE" monitor optimized rekey
set vpn "Site-A_PRI-Site-B_SEC IKE" id 0x4 bind interface tunnel.3
set vpn "Site-A_SEC-Site-B_SEC IKE" gateway "Site-A_SEC-Site-B_SEC" no-replay tunnel idletime 0 proposal "g2-esp-aes128-sha"
set vpn "Site-A_SEC-Site-B_SEC IKE" monitor optimized rekey
set vpn "Site-A_SEC-Site-B_SEC IKE" id 0x5 bind interface tunnel.4
```

From the GUI you should be able to check that these have come up by going to VPN -> Monitor Status.

We now need to enable OSPF on the trust-vr and configure the interfaces to communicate using OSPF. This should be completed on both the primary and secondary site firewalls.

```
set vrouter trust-vr protocol ospf
set vrouter trust-vr protocol ospf enable
set vrouter trust-vr
  set interface tunnel.1 protocol ospf area 0.0.0.0
  set interface tunnel.1 protocol ospf enable
  set interface tunnel.1 protocol ospf priority 10
  set interface tunnel.1 protocol ospf cost 1
  set interface tunnel.1 protocol link-type p2p
  set interface tunnel.2 protocol ospf area 0.0.0.0
  set interface tunnel.2 protocol ospf enable
  set interface tunnel.2 protocol ospf priority 20
  set interface tunnel.2 protocol ospf cost 2
  set interface tunnel.2 protocol link-type p2p
  set interface tunnel.3 protocol ospf area 0.0.0.0
  set interface tunnel.3 protocol ospf enable
  set interface tunnel.3 protocol ospf priority 30
  set interface tunnel.3 protocol ospf cost 3
  set interface tunnel.3 protocol link-type p2p
  set interface tunnel.4 protocol ospf area 0.0.0.0
  set interface tunnel.4 protocol ospf enable
  set interface tunnel.4 protocol ospf priority 40
  set interface tunnel.4 protocol ospf cost 4
  set interface tunnel.4 protocol link-type p2p
  set interface bgroup0 protocol ospf area 0.0.0.0
  set interface bgroup0 ospf passive
  set interface bgroup0 ospf enable

```

You can check the OSPF status by running the following command

```
get vr trust-vr protocol ospf neighbor
```

Finally we need to setup policies to allow traffic to flow across the VPN between the two sites.

```
set address Trust "Site A LAN (192.168.1.0/24)" 192.168.1.0/24
set address VPNZone "Site B LAN (192.168.1.0/24)" 192.168.1.0/24
set policy from Trust to VPNZone "Site A LAN (192.168.1.0/24)" "Site B LAN (192.168.1.0/24)" any permit
set policy from VPNZone to Trust "Site B LAN (192.168.1.0/24)" "Site A LAN (192.168.1.0/24)" any permit
```

To test this you need to take down the Internet connections one by one and watch the routing table update on each firewall. You should now see all four IPSec VPN Tunnels show as active and the route between sites will be via the Layer-3 tunnel interface for the relevant tunnel.

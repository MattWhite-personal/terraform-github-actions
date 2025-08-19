---
title: "ESXi enabling SNMP"
pubDate: "2010-02-10"
categories:
  - "it"
  - "monitoring"
tags:
  - "dell"
  - "esx"
  - "hp"
  - "monitoring"
  - "snmp"
heroImage: "/blog-monitoring-header.png"
description: "Historical technote about the availability of SNMP via ESXi and how to turn it on when it is disabled by default"
---

Last night I wrote an article about how to monitor the health of an ESXi server ([link here](http://www.matthewjwhite.co.uk/blog/2010/02/09/monitoring-esxi-server-health-using-nagiosopsview/ "monitoring-esxi-server-health-using-nagiosopsview")) and I wanted to explain a bit more about my findings with SNMP on an ESXi host.

My goal with the monitoring was to use the check_dell and check_hp commands I have found for Nagios/Opsview to monitor the hardware that ESX is running on. The ESXi installs I am working with are using the Dell and HP management agents installed so I thought that everything would work out of the box and enabling SNMP would let me query the different aspects of the hardware.

The official line from VMWare was that SNMP is not enabled on ESXi and with no console cant be enabled. I knew however, having read a recent post on the [TechHead blog](http://www.techhead.co.uk) ([link here](http://www.techhead.co.uk/how-to-view-your-vmware-esxi-hosts-system-log-config-and-datastore-via-a-web-browser)) that you could see the snmp.xml file and this shows that it is not enabled which made me think it must be possible to enable it. I was right.

A quick google came up with [this article](http://communities.vmware.com/thread/204425) and I had a look and this was a fairly simple process to run:

First you need to enter the "unsupported" console on your ESXi server. To do this press **Ctrl+Alt+F1** at your ESX console, now type the word **unsupported** (N.B. you will not see the text on your screen) and press Enter. If all goes well you should see a password prompt, enter your root password here and you should get a warning you are entering a mode that should only be enabled with VMWare support and be presented with a console.

type the following command to enter the VI text editor and start to modify the snmp.xml file:

```
vi /etc/vmware/snmp.xml

```

You should see a single line of text at the top of the screen which is the contents of the xml file. Press **i** to enter Insert mode and change

```
<enabled>false</enabled>

```

to

```
<enabled>true</enabled>

```

Then scroll across and add the community name you want the SNMP agent to respond on and place this between the following tags

```
<communities></communities>

```

so it should look like

```
<communities>public</communities>

```

I wasnt interested in setting up SNMP traps so left this blank and quit the VI editor by press **Esc** to exit insert mode and then **:wq** to write the file and quit the editor.

Finally we need to restart the services on the esx host which can be done with the following command

```
/sbin/services.sh restart

```

Great, SNMP is now enabled so I should be able to get the information from the HP/Dell management agents that I want. Wrong. My snmpwalk of the host provided little to no useful information about what I was trying to unlock.

```
opsview@LON-SVR-MON1:~$ snmpwalk -v 2c -c public 10.9.0.65
SNMPv2-MIB::sysDescr.0 = STRING: VMware ESX 4.0.0 build-219382 VMware, Inc. x86_64
SNMPv2-MIB::sysObjectID.0 = OID: SNMPv2-SMI::enterprises.6876.4.1
DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (6061646) 16:50:16.46
SNMPv2-MIB::sysContact.0 = STRING: not set
SNMPv2-MIB::sysName.0 = STRING: lon-svr-esx2.domain.local
SNMPv2-MIB::sysLocation.0 = STRING: not set
SNMPv2-MIB::sysServices.0 = INTEGER: 72
SNMPv2-MIB::sysORLastChange.0 = Timeticks: (0) 0:00:00.00
SNMPv2-MIB::sysORID.1 = OID: SNMPv2-MIB::snmpMIB
SNMPv2-MIB::sysORID.2 = OID: IF-MIB::ifMIB
SNMPv2-MIB::sysORID.3 = OID: SNMPv2-SMI::enterprises.6876.1.10
SNMPv2-MIB::sysORID.4 = OID: SNMPv2-SMI::enterprises.6876.2.10
SNMPv2-MIB::sysORID.5 = OID: SNMPv2-SMI::enterprises.6876.3.10
SNMPv2-MIB::sysORDescr.1 = STRING: SNMPv2-MIB, RFC 3418
SNMPv2-MIB::sysORDescr.2 = STRING: IF-MIB, RFC 2863
SNMPv2-MIB::sysORDescr.3 = STRING: VMWARE-SYSTEM-MIB, REVISION 200801120000Z
SNMPv2-MIB::sysORDescr.4 = STRING: VMWARE-VMINFO-MIB, REVISION 200810230000Z
SNMPv2-MIB::sysORDescr.5 = STRING: VMWARE-RESOURCES-MIB, REVISION 200810150000Z
SNMPv2-MIB::sysORUpTime.1 = Timeticks: (0) 0:00:00.00
SNMPv2-MIB::sysORUpTime.2 = Timeticks: (0) 0:00:00.00
SNMPv2-MIB::sysORUpTime.3 = Timeticks: (0) 0:00:00.00
SNMPv2-MIB::sysORUpTime.4 = Timeticks: (0) 0:00:00.00
SNMPv2-MIB::sysORUpTime.5 = Timeticks: (0) 0:00:00.00
IF-MIB::ifNumber.0 = INTEGER: 4
IF-MIB::ifDescr.1 = STRING: Device vmnic0 at 02:00.0 bnx2
IF-MIB::ifDescr.2 = STRING: Device vmnic1 at 02:00.1 bnx2
IF-MIB::ifDescr.3 = STRING: Device vmnic2 at 03:00.0 bnx2
IF-MIB::ifDescr.4 = STRING: Device vmnic3 at 03:00.1 bnx2
IF-MIB::ifType.1 = INTEGER: ethernetCsmacd(6)
IF-MIB::ifType.2 = INTEGER: ethernetCsmacd(6)
IF-MIB::ifType.3 = INTEGER: ethernetCsmacd(6)
IF-MIB::ifType.4 = INTEGER: ethernetCsmacd(6)
IF-MIB::ifMtu.1 = INTEGER: 1500
IF-MIB::ifMtu.2 = INTEGER: 1500
IF-MIB::ifMtu.3 = INTEGER: 1500
IF-MIB::ifMtu.4 = INTEGER: 1500
IF-MIB::ifSpeed.1 = Gauge32: 1000000000
IF-MIB::ifSpeed.2 = Gauge32: 1000000000
IF-MIB::ifSpeed.3 = Gauge32: 0
IF-MIB::ifSpeed.4 = Gauge32: 0
IF-MIB::ifPhysAddress.1 = STRING: 18:a9:5:4e:a7:1c
IF-MIB::ifPhysAddress.2 = STRING: 18:a9:5:4e:a7:1e
IF-MIB::ifPhysAddress.3 = STRING: 18:a9:5:4e:a7:20
IF-MIB::ifPhysAddress.4 = STRING: 18:a9:5:4e:a7:22
IF-MIB::ifAdminStatus.1 = INTEGER: up(1)
IF-MIB::ifAdminStatus.2 = INTEGER: up(1)
IF-MIB::ifAdminStatus.3 = INTEGER: up(1)
IF-MIB::ifAdminStatus.4 = INTEGER: up(1)
IF-MIB::ifOperStatus.1 = INTEGER: up(1)
IF-MIB::ifOperStatus.2 = INTEGER: up(1)
IF-MIB::ifOperStatus.3 = INTEGER: down(2)
IF-MIB::ifOperStatus.4 = INTEGER: down(2)
IF-MIB::ifLastChange.1 = Timeticks: (0) 0:00:00.00
IF-MIB::ifLastChange.2 = Timeticks: (0) 0:00:00.00
IF-MIB::ifLastChange.3 = Timeticks: (0) 0:00:00.00
IF-MIB::ifLastChange.4 = Timeticks: (0) 0:00:00.00
SNMPv2-MIB::snmpInPkts.0 = Counter32: 187
SNMPv2-MIB::snmpInBadVersions.0 = Counter32: 0
SNMPv2-MIB::snmpInBadCommunityNames.0 = Counter32: 0
SNMPv2-MIB::snmpInBadCommunityUses.0 = Counter32: 0
SNMPv2-MIB::snmpInASNParseErrs.0 = Counter32: 0
SNMPv2-MIB::snmpEnableAuthenTraps.0 = INTEGER: disabled(2)
SNMPv2-MIB::snmpSilentDrops.0 = Counter32: 0
SNMPv2-MIB::snmpProxyDrops.0 = Counter32: 0

```

My thoughts now are simple. SNMP is not enabled in ESXi for the reason that there is not much there to query and you can use the CIM queries that I mentioned in the previous post to look at this instead.

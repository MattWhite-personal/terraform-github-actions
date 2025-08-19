---
title: "Monitoring Alarm Status on Juniper EX Switches"
pubDate: "2012-08-16"
categories:
  - "it"
  - "monitoring"
  - "networking"
tags:
  - "juniper"
  - "monitoring"
  - "opsview"
  - "switch"
heroImage: "/blog-network-header.png"
description: "Historical post that looks at how to enable OID monitoring of chassis alarms on Juniper EX switches using monitoring tools such as Negios, Zabbix or Opsview"
---

I am in the process of installing a number of Juniper EX2200, EX3200 and EX4200 switches for a client and as part of the setup need to be able to monitor the switches for any alarms  (eg Switch Management interface down or Switch booted from Backup Partition) and have them dealt with accordingly.

Having a look at the SNMP OID tree for the EX switches I came across the following useful table

[http://www.oidview.com/mibs/2636/JUNIPER-ALARM-MIB.html](http://www.oidview.com/mibs/2636/JUNIPER-ALARM-MIB.html)

| Object Name                                                                                | Object Identifier          |
| ------------------------------------------------------------------------------------------ | -------------------------- |
| ![jnxYellowAlarmState](/images/tree.gif) jnxAlarmsjnxAlarms                                | 1.3.6.1.4.1.2636.3.4       |
| ![jnxYellowAlarmState](/images/object.gif)jnxCraftAlarmsjnxCraftAlarms                     | 1.3.6.1.4.1.2636.3.4.2     |
| ![jnxYellowAlarmState](/images/object.gif)jnxAlarmRelayModejnxAlarmRelayMode               | 1.3.6.1.4.1.2636.3.4.2.1   |
| ![jnxYellowAlarmState](/images/object.gif)jnxYellowAlarmsjnxYellowAlarms                   | 1.3.6.1.4.1.2636.3.4.2.2   |
| ![jnxYellowAlarmState](/images/object.gif)jnxYellowAlarmStatejnxYellowAlarmState           | 1.3.6.1.4.1.2636.3.4.2.2.1 |
| ![jnxYellowAlarmState](/images/object.gif)jnxYellowAlarmCountjnxYellowAlarmCount           | 1.3.6.1.4.1.2636.3.4.2.2.2 |
| ![jnxYellowAlarmState](/images/object.gif)jnxYellowAlarmLastChangejnxYellowAlarmLastChange | 1.3.6.1.4.1.2636.3.4.2.2.3 |
| ![jnxYellowAlarmState](/images/object.gif)jnxRedAlarmsjnxRedAlarms                         | 1.3.6.1.4.1.2636.3.4.2.3   |
| ![jnxYellowAlarmState](/images/object.gif)jnxRedAlarmStatejnxRedAlarmState                 | 1.3.6.1.4.1.2636.3.4.2.3.1 |
| ![jnxYellowAlarmState](/images/object.gif)jnxRedAlarmCountjnxRedAlarmCount                 | 1.3.6.1.4.1.2636.3.4.2.3.2 |
| ![jnxYellowAlarmState](/images/object.gif)jnxRedAlarmLastChangejnxRedAlarmLastChange       | 1.3.6.1.4.1.2636.3.4.2.3.3 |

I have used the jnxRedAlarmCount and jnxYellowAlarmCount oid values as basic Opsview SNMP Service Checks to give me an initial overview but in the long term will be looking to combine this into a full service check script that can be used to check a number of different things.

The setup of the Service Check in Opsview is fairly simple and below are screenshots of the config that I have for each service check.

![](/images/chassisalarmsred.png "Chassis Alarms Red")

![](/images/chassisalarmsyellow.png "Chassis Alarms Yellow")

All you need to configure on your hosts is the SNMP community string and you can apply these checks individually or via a Host Template.

Once I performed a reload I could see the following in Opsview for one of my switches:

![](/images/chassisalarms.png "Chassis Alarms")

A bit of inspection showed that the Red Alarm was for the Management Interface being down (but wasnt being used on this switch) and the Yellow alarm was due to not setting a rescue configuration. I cleared the alarms by isuing the following commands

```
edit
set chassis alarms management-interface link-down ignore
commit and-quit
request system configuration rescue save
```

Now when I refresh the checks in Opsview I get an OK state for both checks

---
title: "JunOS: Logout stale edit sessions"
pubDate: "2013-02-28"
categories:
  - "it"
  - "networking"
tags:
  - "juniper"
  - "junos"
heroImage: "/blog-network-header.png"
description: "Short technote that describes how to logout a stale user session on a JunOS device"
---

I have been bitten enough times when my ssh session to my JunOS switch or router has been disconnected because it was idle and then when I reconnect get the warning to say that another user is editing the configuration.

```
adminuser@switch01> edit
Entering configuration mode
Users currently editing the configuration:
adminuser terminal p0 (pid 28439) on since 2013-02-28 14:27:28 GMT, idle 01:41:42
[edit]

```

The easiest thing to do is to log out the other session once you have reconnected to the device by using the PID of the stale session (in this case 28439) with the following command:

```
request system logout pid 28439
```

You should now no longer see that message when you log back into the switch.

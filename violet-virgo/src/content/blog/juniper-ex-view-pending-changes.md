---
title: "Juniper EX view pending changes"
pubDate: "2012-04-13"
categories:
  - "it"
  - "networking"
tags:
  - "ex"
  - "juniper"
  - "switch"
heroImage: "/blog-network-header.png"
description: "Short technote that describes how to compare the pending changes to a JunOS device against the current running configuration"
---

When making changes to Juniper EX switches yesterday I wanted to check the changes that I had made to my configuration before committing them. A quick look in the reference manual gave me the following command:

```
show | compare rollback 0
```

This will show the edited candidate config and pipe that into the compare function and look at the changes to the specified version (rollback 0). I could look at the changes compared to a previous config by replacing 0 with another number in the rollback sequence.

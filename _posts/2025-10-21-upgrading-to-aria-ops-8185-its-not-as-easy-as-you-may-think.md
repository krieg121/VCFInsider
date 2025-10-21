---
layout: post
title: "Upgrading to Aria Ops 8.18.5? It’s not as easy as you may think."
categories: ["cloud-foundation"]
tags: [aria-operations, vcf, lcm, vidm]
author: "Chris"
description: "Upgrading to Aria Ops 8.18.5? It’s not as easy as you may think."
image: /assets/images/posts/aria-ops-8185/vRops_8.18.5.png
---

Upgrading to Aria Ops 8.18.5? It’s not as easy as you may think.





VMware recently released a security update for Aria Ops (vRops for the old school guys out there…which is how I’m going to refer to it from now on) VMSA 2025-0015 () Basically it says you will need to upgrade vRops to 8.18.5 to fix the issue. Sounds simple enough right? Well, its not. If you take time to read documentation like I do, you will notice that in order to get vRops to 8.18.5, you will need to upgrade LCM to patch 5 also. Ok, no big deal…well if you read LCM patch 5’s documentation, it will tell you you need to upgrade vIDM (identity manager/workspace one) first. My experience with vIDM is less than pleasant. Thank GOD it’s being deprecated with VCF 9.x Anyways, I recently went through the upgrade process in my lab. From vIDM to vRops. The LCM and vRops upgrades went smooth for most part but I did have some issues to work through. I wrote up a KB on process steps, that way you don’t have to fish through multiple KBs to figure out the logical order. I also included the KBs I used to work through the issues I ran into.



Note: As of this writing, the vIDM upgrade has a serious issue. The upgrade causes database corruption! After the upgrade the Opensearch service wouldn’t start. I tried a few KBs,







After these didn’t work, I finally opened a ticket w/ VMware support. In short, the error message I was getting “Error creating bean with name Liquibase defined in class path resource [spring/datastore-connection-wireup.xml]: invocation of init method failed; nested exception is Liquibase.exception.databaseException: org.postgresql.util.PSQLException: The connection attempt failed”.

And

Getting this when trying KB401750

“pgpool error while loading shared libraries:libpq.so.5”

“libpq.so.5 exists in /opt/vmware/vpostgress/14/lib/. PGPool fails to start and never generates the temp files…”



According to what I’ve learned, this issue has garnered the attention of VMware engineering. I will hopefully get a fix/workaround soon and be able to test it in my lab. I will post updates as I progress through the vIDM issue.

On another note, this issue didn’t affect my LCM and vRops upgrade. I would be interested to hear your experiences on these upgrades. Meanwhile, I will share my KB (minus confidential company information of course) to help anyone with getting their head around these upgrades.





-C



Categories: Aria Operations, Cloud Foundation

Tags: VCF, Aria Operations, LCM, vIDM, VMSA-2025-0015

Description: Upgrading Aria Ops to 8.18.5 is not as easy as you think. It’s actually 3 upgrades! Major bug with one of the patches that causes database corruption.

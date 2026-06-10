---

layout: post
title: "The Matrix Did Not Show the Full Story"
date: 2026-06-12 09:00:00 -0400
author: "Chris Kitchens"
categories: ["Cloud Foundation"]
tags: ["VCF", "VMware Cloud Foundation", "SDDC Manager", "Avi", "Avi Load Balancer", "NSX", "NSX ALB", "Interoperability Matrix", "Upgrade", "Lifecycle", "GSS"]
description: "After Avi / NSX ALB 22.1.6 blocked the VCF 9.0.2 management domain upgrade plan, the Broadcom Interoperability Matrix did not show the full upgrade path."
excerpt: "SDDC Manager exposed the Avi blocker, but the Broadcom Interoperability Matrix did not show the full story. GSS confirmed we could upgrade Avi / NSX ALB directly from 22.1.6 to 31.2.1, clearing the path for VCF 9.0.2."
image: /assets/images/posts/2026-06-12-when-your-version-is-not-even-in-the-matrix/hero.webp
thumbnail: /assets/images/posts/2026-06-12-when-your-version-is-not-even-in-the-matrix/hero.webp
og_image: /assets/images/posts/2026-06-12-when-your-version-is-not-even-in-the-matrix/hero.webp
---

# The Matrix Did Not Show the Full Story

In [Part 1](/cloud%20foundation/2026/06/10/the-upgrade-plan-was-ready-avi-was-not/), the VCF 9.0.2 management domain upgrade looked ready.

SDDC Manager was already running 9.0.2. The target version showed up in the Plan Upgrade workflow. From a distance, it looked like we were ready to move forward.

Then SDDC Manager stopped the plan.

The compatibility check pointed directly at NSX ALB / Avi Load Balancer 22.1.6.

That part was clear.

What was not clear was what version we should upgrade Avi to next.

## The Blocker Was Avi

The original SDDC Manager compatibility check showed that the target VCF 9.0.2 component stack was not interoperable with the installed Avi version.

The important relationships were:

| Target Component    | Existing Dependency  | Compatibility Result |
| ------------------- | -------------------- | -------------------- |
| vCenter 9.0.2.0     | NSX ALB / Avi 22.1.6 | Not interoperable    |
| NSX Manager 9.0.2.0 | NSX ALB / Avi 22.1.6 | Not interoperable    |

That told us the management domain upgrade was not going anywhere until Avi / NSX ALB was addressed.

Simple enough.

Except the next question was the part that needed some care:

What version of Avi do we go to?

That is where the Broadcom Interoperability Matrix came into the picture.

## The Matrix Did Not Show the Full Story

When we checked the Broadcom Interoperability Matrix, the odd part was not that Avi / NSX ALB 22.1.6 existed.

It did.

The odd part was that 22.1.6 was not available as a selectable Avi Load Balancer version in the matrix view we were using.

<img src="/assets/images/posts/2026-06-12-when-your-version-is-not-even-in-the-matrix/broadcom-interop-matrix-avi-version-list.jpg" alt="Broadcom Interoperability Matrix showing Avi Load Balancer versions without 22.1.6 available as a selectable version" width="78%">

That was the part worth writing down.

Not because it was some dramatic outage or massive upgrade failure.

It was just one of those real-world lifecycle details that can burn time if you assume the matrix is telling you everything.

We knew the installed version was 22.1.6. We knew SDDC Manager did not like it for the VCF 9.0.2 target stack. But the matrix was not giving us a clean answer for the exact version we were running.

So we did not guess.

## GSS Confirmed the Path

At that point, the right move was to work with GSS and confirm the upgrade target.

We needed to know whether we could go directly from Avi / NSX ALB 22.1.6 to a newer version that would satisfy the VCF 9.0.2 compatibility requirement.

GSS confirmed the target: 31.2.1.

And in our case, we went straight to it.

No intermediate step.

The path was:

| Component     | Starting Version | Target Version | Result                                   |
| ------------- | ---------------: | -------------: | ---------------------------------------- |
| Avi / NSX ALB |           22.1.6 |         31.2.1 | VCF 9.0.2 Plan Upgrade became selectable |

That was the useful finding.

Even though the website did not make the path obvious from 22.1.6, GSS confirmed that we could upgrade directly to 31.2.1.

After Avi / NSX ALB was upgraded to 31.2.1, we went back to SDDC Manager and checked the Plan Upgrade workflow again.

This time, VCF 9.0.2 could be selected.

## Why This Matters

This is one of those upgrade details that does not look like much until you are the one staring at the blocker.

When most people think about a VCF management domain upgrade, they think about the usual suspects:

* SDDC Manager
* vCenter
* ESXi
* vSAN
* NSX Manager

That makes sense. Those are the obvious lifecycle components.

Avi / NSX ALB can feel a little separate from that path. Depending on the environment, it may not feel like the thing you planned to touch that day.

But SDDC Manager still evaluated it as part of the compatibility chain.

That is the important part.

Even if Avi feels separate from the main VCF lifecycle workflow, it can still stop the workflow from moving forward.

## What Actually Happened

The original plan was pretty basic:

1. Select VCF 9.0.2 in SDDC Manager
2. Plan the management domain upgrade
3. Move forward with the lifecycle workflow

The real path looked more like this:

1. Select VCF 9.0.2 in SDDC Manager
2. Hit the Avi / NSX ALB compatibility blocker
3. Check the Broadcom Interoperability Matrix
4. Notice that 22.1.6 was not shown as a selectable Avi version
5. Work with GSS to confirm the supported target
6. Upgrade Avi / NSX ALB directly from 22.1.6 to 31.2.1
7. Return to SDDC Manager
8. Select VCF 9.0.2 in Plan Upgrade

That is not some crazy upgrade saga.

It is just real infrastructure work.

The button says Plan Upgrade, but the environment still gets a vote.

## What I Would Check Next Time

Before planning another VCF management domain upgrade, I would check Avi / NSX ALB earlier.

At minimum, I would validate:

* Current Avi / NSX ALB version
* Whether that version appears in the Broadcom Interoperability Matrix
* Compatibility between Avi and the target VCF component stack
* Whether the target Avi version keeps the VCF upgrade path moving
* Whether GSS guidance is needed if the installed version does not show cleanly in the matrix
* Whether SDDC Manager Plan Upgrade behavior changes after Avi is upgraded

That last one matters.

The real validation was not just completing the Avi upgrade.

The real validation was going back to SDDC Manager and confirming that VCF 9.0.2 could now be selected in the Plan Upgrade workflow.

## Lesson Learned

The matrix is important, but it may not tell the full story.

In this case, it helped confirm that we had a version gap, but it did not clearly show the path from the exact installed version.

GSS helped close that gap.

After upgrading Avi / NSX ALB from 22.1.6 to 31.2.1, SDDC Manager allowed the VCF 9.0.2 management domain upgrade plan to move forward.

That is the part worth remembering.

Avi was not the upgrade we started with.

But it was the upgrade we had to finish before the management domain upgrade could continue.

---

## Continue the Conversation

Have you run into VCF lifecycle blockers, Avi / NSX ALB compatibility issues, or upgrade paths where the matrix did not show the full story?

Join the discussion in the **VCF Insider Community**, an independent space for VMware Cloud Foundation engineers, homelab builders, and anyone working through real-world VCF deployments, troubleshooting, automation, and lessons learned.

[Visit the VCF Insider Community](https://community.vcfinsider.com)

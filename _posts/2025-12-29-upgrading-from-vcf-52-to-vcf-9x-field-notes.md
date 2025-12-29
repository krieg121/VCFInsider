---
layout: post
title: "Upgrading from VCF 5.2 to VCF 9.x"
subtitle: "Field Notes from a Live Lab Upgrade"
date: 2025-12-29 09:00:00 -0500
author: Chris Kitchens
categories: ["Cloud Foundation"]
tags:
  - vcf
  - vcf9
  - upgrade
  - lifecycle
  - field-notes
  - aria
description: "Field notes from a live lab upgrade documenting the real-world gap between supported VCF 5.2 to 9.x upgrade paths and operational reality."
image: /assets/images/posts/2025-vcf9-field-notes/vcf9-field-notes_1920x1080.webp
thumbnail: /assets/images/posts/2025-vcf9-field-notes/vcf9-field-notes_1920x1080.webp
og_image: /assets/images/posts/2025-vcf9-field-notes/vcf9-field-notes_1920x1080.webp
body_class: field-notes
---

## Upgrading from VCF 5.2 to VCF 9.x  
### *Field Notes from a Live Lab Upgrade*

This is not a how-to guide.

This is not a success story written after the dust settles.

This is a set of **field notes** from a live lab upgrade — documenting what actually happens when you take a VMware Cloud Foundation 5.2 environment and start pushing it toward 9.x.

I recently completed VCF 9.x training and immediately began preparing a lab to validate the upgrade path. What became clear very quickly is that the distance between **“supported on paper”** and **“comfortable in practice”** is much wider than the training material suggests.

This series exists to document that gap.

---

## Why This Upgrade Starts in a Lab (and Stays There for Now)

Moving from VCF 5.2 to 9.x is not a routine lifecycle event. This is not a minor version bump or a familiar SDDC Manager workflow you’ve run a dozen times before.

This is a **generational jump**.

Between those versions, nearly everything that matters has evolved:
- Lifecycle orchestration expectations
- Component version alignment
- Aria suite behavior and dependencies
- NSX integration assumptions
- Operational guardrails that didn’t exist in earlier releases

A lab isn’t optional here. It’s mandatory.

If you discover a dependency gap, an undocumented prerequisite, or a lifecycle sequencing issue in production, you’ve already lost. The lab is where you want surprises. Production is where you want confidence.

This series is intentionally lab-first — because that’s where the real learning happens.

---

## Training vs. Reality (No Complaints, Just Observations)

The VCF 9.x training does a good job of explaining *what* the platform is capable of and *where* VMware wants customers to go.

What it cannot fully capture is **environmental entropy**.

Training environments are clean.  
Labs are not.  
Production environments are worse.

As soon as you leave the training narrative and introduce:
- Legacy configurations
- Drift accumulated over years
- Real authentication, networking, and operational constraints

…the experience changes.

None of this is a criticism of the training. It’s simply the reality that **complex platform upgrades don’t fail loudly — they fail subtly**. The risk isn’t obvious breakage. The risk is misplaced confidence.

That’s what this lab is designed to expose early.

---

## What I’m Watching Closely During This Upgrade

Rather than jumping straight to outcomes, these field notes focus on **signals**.

Here’s what I’m paying close attention to as the upgrade progresses:

- **Lifecycle sequencing**  
  What *must* happen in a specific order versus what appears flexible on paper.

- **Aria alignment**  
  How Aria Operations, Automation, and related services behave as VCF evolves underneath them.

- **NSX expectations**  
  Where assumptions about version compatibility and feature parity don’t line up cleanly.

- **Error handling and recovery paths**  
  Not just what fails — but how confidently it can be rolled back or corrected.

- **Operational blast radius**  
  What changes subtly alter day-2 operations, monitoring, or compliance posture.

These aren’t academic concerns. They’re the things that determine whether an upgrade feels controlled or fragile.

---

## Early Signals (Before the First Real Blocker)

Even at this early stage, one theme is already clear:

**The upgrade is technically supported — but operationally non-trivial.**

That distinction matters.

Nothing so far suggests this upgrade is unsafe. But it *does* demand more preparation, validation, and patience than the version numbers alone would imply.

This is exactly why these notes are being written now — not after everything is cleaned up and summarized.

---

## What’s Coming Next

This post is the starting line.

In upcoming entries, I’ll document:
- The first real friction point encountered in the lab
- Where expectations diverged from reality
- Which assumptions held — and which did not
- What I would do differently before even considering production

These will be written as the work happens. Feel free to ask questions & I am also interested in your experiences with your VCF 9 upgrade. Feel free to post below!

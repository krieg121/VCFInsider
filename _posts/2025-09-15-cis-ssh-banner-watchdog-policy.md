---
layout: post
title: "Automate CIS baseline remediations: SSH logon banner & watchdog policy"
date: 2025-09-15 10:00:00 -0400
categories: [automation]          # machine slug for URLs/listing
category: Automation              # display label used on cards/lists
tags: [Automation, PowerCLI]
featured_image: /assets/images/posts/2025-09-15-cis-ssh-banner-watchdog-policy/cover.png
image: /assets/images/posts/2025-09-15-cis-ssh-banner-watchdog-policy/cover.png
description: "Quick PowerCLI fixes to meet CIS checks: add an SSH logon banner and update ESXi watchdog service policies across your fleet."
---

So recently we went through a CIS audit. We use vROps (VCF Ops now) compliance module to audit our environment.

Some of the items that we are remediating include turning on some simple items, like adding an SSH connection banner, and updating the watchdog service policies.

I wrote a couple of PowerCLI scripts to accomplish this. Feel free to use them.

## What this covers

- Sets a compliant **SSH logon banner** on ESXi hosts
- Updates **ESXi watchdog service policies** per CIS baseline

## Usage

Download the ZIP(s) below and review the README or inline comments before running in your environment.

<div class="original-link-box">
  <h3><i class="fa fa-download"></i> Downloads</h3>
  <a class="original-link-button" href="{{ '/assets/downloads/Update%20SSH%20Logon%20Banner.zip' | relative_url }}" download>
    Update SSH Logon Banner.zip
  </a>
  <a class="original-link-button" href="{{ '/assets/downloads/watchdog%20policy.zip' | relative_url }}" download>
    watchdog policy.zip
  </a>
</div>

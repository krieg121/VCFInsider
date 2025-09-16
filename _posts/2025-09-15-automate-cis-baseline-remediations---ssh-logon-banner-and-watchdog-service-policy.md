---
layout: post
title: "Automate CIS baseline remediations - SSH Logon Banner & Watchdog Service policy"
date: 2025-09-15 09:00:00 -0500
categories: ["AI & Automation"]
tags: [Automation, PowerCLI]
image: /assets/images/posts/2025-09-15-automate-cis-baseline-remediations---ssh-logon-banner-and-watchdog-service-policy/cover.png
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

> Tip: run against a test cluster first, then expand in batches. Take a quick config backup or snapshot of affected settings where possible.
category: "AI category: AI & Automation Automation"

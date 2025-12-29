---
layout: post
title: "Mastering CIS Remediation at Scale: Inside My ESXi Hardening Script"
subtitle: "How Master_CIS_Remediation v5.8.6 enforces CIS-aligned settings safely across selected vCenters"
date: 2025-12-29 09:00:00 -0500
author: Chris
categories: ["Security"]
tags:
  - esxi
  - cis
  - compliance
  - hardening
  - powercli
  - automation
  - vcenter
description: "A field-tested look at how my Master_CIS_Remediation v5.8.6 script safely enforces CIS-aligned ESXi settings across selected vCenters—complete with dry-run and backout support."
image: /assets/images/posts/2025-12-29-master-cis-remediation/master-cis-remediation_1920x1080.webp
thumbnail: /assets/images/posts/2025-12-29-master-cis-remediation/master-cis-remediation_1920x1080.webp
og_image: /assets/images/posts/2025-12-29-master-cis-remediation/master-cis-remediation_1920x1080.webp
body_class: field-notes
---

## Why I Built This

CIS alignment is easy to talk about and hard to operationalize.

At any real scale, the problem isn’t “what setting should this be?” — the problem is safely enforcing it across hundreds (or thousands) of hosts, across multiple vCenters, without breaking operations, without losing audit evidence, and with a clean way to unwind changes if something unexpected surfaces.

That’s what **Master_CIS_Remediation v5.8.6** is designed to do:
- enforce CIS-aligned ESXi host configuration
- log every action
- provide a dry-run mode
- and support backout using a captured backup CSV

This is not a one-off “run it once and forget it” script. It’s meant to be a repeatable compliance tool.

---

## Design Goals

These were my non-negotiables when building this:

- **PowerShell 5.1 compatible**
- **Operator-friendly UX** (same flow and feel as my Audit script)
- **Idempotent checks** (if the host is already compliant, do nothing)
- **Evidence-first logging** (every pass/fail/change is recorded)
- **Backout-capable by design** (restore from captured pre-change values)

---

## Script Modes

The script supports three execution modes:

### AuditOnly (dry run)
Runs all checks, **makes no changes**, and **skips change logging**.

### Remediation (default)
Performs the checks and applies changes when non-compliance is found.

### Backout
Restores settings from a **backup CSV** produced during a remediation run.

---

## Credential Handling (Multi-vCenter Friendly)

This script supports a simple, repeatable credential workflow using exported credential files. The credential file is created per vCenter FQDN and stored here:

`%USERPROFILE%\Documents\vcentercreds\<vcenter>.xml`

This keeps the operator experience smooth when you’re frequently adding new vCenters.

---

## Logging (Proof Matters)

All output CSVs land in:

`C:\Temp`

The script writes distinct outputs for clarity:

- **Remediation results:** `Master_CIS_Remediation_<timestamp>.csv`
- **Backups for backout:** `Master_CIS_Backup_<timestamp>.csv`
- **Backout results:** `Master_CIS_Backout_<timestamp>.csv`

This separation is intentional:
- remediation = “what I changed”
- backup = “what it was before”
- backout = “what I restored”

---

## What It Enforces (v5.8.6)

The v5.8.6 menu-driven checks include:

- `Mem.ShareForceSalting`
- `ESXi Shell (TSM)`
- `SSH (TSM-SSH)`
- `NTP & ntpd`
- `SNMP`
- `Persistent logging`
- `Remote logging`
- `SSH Connection Banner`
- `SLP service (slpd)`
- `SSH service policy Manual`
- `Account lockout failures`
- `DVFilter Bind IP`
- `Password Complexity`
- `Managed Object Browser (MOB)`
- `Hyperthreading warning`
- `iSCSI Mutual CHAP (may require reboot)`

---

## How to Run It

### Dry run (recommended first)
```powershell
.\Master_CIS_Remediation_v5.8.6.ps1 -AuditOnly
```

### Remediation run
```powershell
.\Master_CIS_Remediation_v5.8.6.ps1
```

### Backout run
```powershell
.\Master_CIS_Remediation_v5.8.6.ps1 -Backout
```

Or specify the CSV directly:
```powershell
.\Master_CIS_Remediation_v5.8.6.ps1 -Backout -BackoutCsv "C:\Temp\Master_CIS_Backup_YYYYMMDD_HHMMSS.csv"
```

---

## Operational Notes I Care About

- Run **AuditOnly first** to validate scope and reduce surprises.
- Keep evidence CSVs like change tickets.
- CIS controls can have real operational impact—roll out carefully.
- Backout is not optional; it’s how you build trust in automation.

---

## What’s Next

This script is one piece of a broader compliance workflow. Future directions include enhanced reporting, tighter pre-flight checks, and deeper control-to-risk mapping. If you’re running ESXi at scale and trying to keep standards consistent without living in manual remediation forever, this approach is worth building into your toolbox.

## Download the Script

A public, sanitized version of this script is available for download below.

👉 [Download Master_CIS_Remediation_v5.8.6_SANITIZED.ps1](/assets/downloads/scripts/Master_CIS_Remediation_v5.8.6_PUBLIC.ps1)

> ⚠️ This script is provided as-is for educational purposes.  
> Always review and test in a lab environment before running in production.


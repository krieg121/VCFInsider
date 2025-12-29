---
layout: page
title: "Scripts & Toolkits"
permalink: /resources/scripts/
description: "Field-tested automation scripts and toolkits used in real VMware Cloud Foundation environments."
---

## 🛠 Scripts & Toolkits

This page centralizes **public, sanitized scripts** shared on VCF Insider.  
All scripts are based on real-world use in enterprise VMware Cloud Foundation environments.

> **Important:**  
> Scripts are provided as-is. Review and test in a lab or non-production environment before running in production.

---

## Master CIS Remediation Toolkit

**Purpose**  
Enforces CIS-aligned ESXi host configuration settings at scale across one or more vCenters.

**Key Capabilities**
- Audit-only mode (no changes)
- Enforcement mode with CSV logging
- Backout mode to restore previous settings
- Designed for large-scale, repeatable execution

**Tested With**
- VMware Cloud Foundation
- vSphere 7.x / 8.x
- PowerShell 5.1 + PowerCLI

**Downloads**
- 👉 [Download Master_CIS_Remediation_v5.8.6_SANITIZED.ps1]({{ '/assets/downloads/scripts/Master_CIS_Remediation_v5.8.6_SANITIZED.ps1' | relative_url }})

**Related Article**
- [Master CIS Remediation at Scale – Lessons from the Field](/cloud-foundation/2025/12/29/master-cis-remediation-at-scale/)

---

## Notes on Availability

- Only **sanitized** versions are published publicly
- Environment-specific values are intentionally removed
- Version numbers are included to avoid ambiguity

Additional scripts may be added over time as they are validated and prepared for public release.

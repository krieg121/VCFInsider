---
layout: post
title: "URGENT: Aria Operations & VMware Tools Updates — VMSA-2025-0015"
subtitle: "Patch to Aria Operations 8.18.5 and VMware Tools 13.0.5 / 12.5.4"
date: 2025-10-07 10:00:00 -0400
author: Chris
description: "Broadcom VMSA-2025-0015 addresses CVE-2025-41244, CVE-2025-41245, and CVE-2025-41246 affecting Aria Operations, VMware Tools, and VCF Operations."
categories: [Security]
tags: [Aria Operations, VMware Tools, VCF, VMSA-2025-0015, CVE-2025-41244, CVE-2025-41245, CVE-2025-41246]
featured_image: /assets/images/posts/2025-10-07-aria-operations-vmsa-2025-0015/cover.png
---

> **Heads-up for VCF & Aria Ops teams:** Broadcom released **VMSA-2025-0015** covering three vulnerabilities across **Aria Operations** and **VMware Tools**. There are **no workarounds** — patch to the fixed versions listed below.

## TL;DR (What to patch)
- **Aria Operations:** update to **8.18.5**
- **VCF Operations:** update to **9.0.1.0**
- **VMware Tools:** update to **13.0.5.0** (or **12.5.4** for older branches)
- **Scope:** Impacts Aria Operations (8.x), VMware Tools (Windows/Linux; 41246 is Windows-only), and VCF Ops bundles.
- <span style="color: var(--vmware-blue);">NOTE:Currently upgrading your vROPS to this hotfix will prevent you from upgrading to VCF 9. In the patch documentation you will notice a sentence that says "An upgrade of Aria Ops to 8.18.5 to VCF 9.0.1.0 is not permitted." So if you are planning on upgrading to VCF 9.x at some point, I would wait for VMware to release the upgradeable version which either will be 9.0.1.1 or 9.0.1.2.</span> 

## The vulnerabilities
- **CVE-2025-41244 — Local Privilege Escalation (up to CVSS 7.8)**  
  On VMs with **VMware Tools** that are **managed by Aria Operations** with **SDMP enabled**, a local non-admin could escalate to **root** on the same VM.

- **CVE-2025-41245 — Information Disclosure (CVSS 4.9)**  
  A **non-admin** in **Aria Operations** could disclose **credentials of other Aria users**.

- **CVE-2025-41246 — Improper Authorization in VMware Tools for Windows (CVSS 7.6)**  
  A non-admin on a **guest Windows VM**, already authenticated in vCenter/ESXi, could access **other guest VMs** under certain conditions.  
  *Note: This one affects **Windows** Tools; Linux/macOS Tools are listed as unaffected.*

> Broadcom lists the overall severity as **Important**, with **CVSSv3 4.9–7.8** across issues.

## Fixed versions (install these)
- **Aria Operations** → **8.18.5**  
- **VCF Operations** → **9.0.1.0**  
- **VMware Tools** → **13.0.5.0** (current), **12.5.4** (updates for 12.x & Windows 32-bit noted)

## What I recommend for VCF environments
1. **Inventory**: Identify all Aria Ops instances and bundled VCF Operations components.  
2. **Prioritize**: Patch management clusters first; then workload domains.  
3. **Tools at scale**: Use **vSphere Lifecycle Manager** or your endpoint tooling to update VMware Tools fleet-wide.  
4. **Validate**: After patching, confirm Aria Ops services are healthy and Tools versions report as **13.0.5.0** (or **12.5.4** where applicable).  
5. **Hardening check**: If you use **SDMP** with Aria Ops, ensure policies are aligned post-upgrade.

## References
- Broadcom Security Advisory **VMSA-2025-0015** (Aria Operations & VMware Tools)  
  https://support.broadcom.com/web/ecx/support-content-notification/-/external/content/SecurityAdvisories/0/36149

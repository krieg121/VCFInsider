---
layout: post
title: "Aria Operations 8.18.5 Upgrade to VCF Operations 9.0.2 (Lab Field Notes)"
subtitle: "Error free...for the most part"
date: 2026-02-03 09:00:00 -0500
author: Chris
categories: ["Cloud Foundation"]
tags: ["vcf","vcf-operations","aria-operations","upgrade","lifecycle-manager","dns","field-notes"]
description: "Field notes from upgrading Aria Operations 8.18.5 to VCF Operations 9.0.2, including a vCenter/cluster dropdown issue in Fleet Management and a DNS hostname typo that blocked progress."
image: /assets/images/posts/2026-02-03-aria-ops-8-18-5-upgrade-to-vcf-operations-9-0-2/hero.webp
thumbnail: /assets/images/posts/2026-02-03-aria-ops-8-18-5-upgrade-to-vcf-operations-9-0-2/hero.webp
og_image: /assets/images/posts/2026-02-03-aria-ops-8-18-5-upgrade-to-vcf-operations-9-0-2/hero.webp
---

Over the last week or so, I upgraded our lab **Aria Operations (vROps) 8.18.5** to **VCF Operations 9.0.2**. For the most part it went smoothly, but I hit a couple of issues that are worth calling out.

## Docs I followed

VCF Operations upgrade guide:  
  - [VCF 9.x docs: Upgrade to VCF Operations](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/deployment/upgrading-cloud-foundation/preparing-your-vcf-9-management-components/upgrading-management-components/upgrade-to-vcf-operations.html)

Upgrade guide reference if you’re **not** upgrading through VCF Lifecycle/LCM:  
 - [VCF 9.x docs: Upgrade / Backup / Restore (non-VCF path)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/deployment/upgrading-cloud-foundation/preparing-your-vcf-9-management-components/upgrade-backup-and-restore.html)
## Key prerequisite

If you’re on **Aria Operations 8.18.5** and targeting **VCF Operations 9.0.2**, make sure your **Aria Suite Lifecycle (vRSLCM)** is updated to **8.18.0 Patch 6** first—otherwise LCM may not recognize the 9.0.2 upgrade path.

## Binaries and basic prep

Download the following binaries to the **/data** partition on your Aria Suite Lifecycle appliance:

- OVA: `VCF-OPS-Lifecycle-Manager-Appliance-9.0.0.X.XXXXXXX.ova`
- PAK: `Operations-Upgrade-9.0.0.X.XXXXXXXX.pak`

Environment checks:

- Ensure the Fleet Management appliance has a valid **FQDN** with **forward and reverse DNS** resolving correctly.
- Have a **15+ character password** ready for both `root` and `admin@local` for the Fleet Management appliance.

## Mapping binaries in Aria Suite Lifecycle

1. Log in to **Aria Suite Lifecycle**.
2. Go to **Lifecycle Operations → Settings → Binary Mapping → Product Binaries**.
3. Click **Add Binaries**.
4. Set **Base Location** to your binaries path (or `/data`) and click **Discover**.
5. Select the **OVA** and **PAK**, then click **Add**.

## Running the upgrade

1. **Lifecycle Operations → Environments**
2. Select the **Aria Operations** environment → **View Details → Upgrade**
3. Let the **inventory sync** run (or click **Trigger Inventory Sync** when prompted)
4. Select:
   - Product Version/Repository URL (9.0.x)
   - License type
5. Click **Run Assessment**
6. Optional: **Take product snapshot**
7. Continue through the steps (LCM ran ~20–22 steps for me)

---

## Issue #1: vCenter/Cluster dropdown was empty during Fleet Mgmt VM properties

During the Fleet Management appliance deployment wizard, I hit an odd issue:

> The dropdown to select **vCenter** and **Cluster** was completely **empty**.

I tried the usual suspects (inventory sync, reboot, retry)… no luck.

### Fix

Broadcom has a KB for it (Solved the problem immediately):

https://knowledge.broadcom.com/external/article/403965/vcenter-server-does-not-appear-in-the-li.html

The short version: delete the existing upgrade request, then run **Refresh Data Collection**. After the refresh, the dropdown populated with my vCenter/cluster inventory as expected.

## Issue #2: DNS (self-inflicted)

My next blocker was DNS… and yeah, this one was on me. I fat-fingered the Fleet Management hostname (missing letters). Once I corrected the DNS record and verified it resolved, the pre-check and upgrade proceeded normally.

**Lesson learned:** slow down and double-check the exact hostname you’re entering in DNS. 😉

## Post-upgrade note: where LCM “moves” to

Once you upgrade to **VCF Operations**, you’ll notice **Aria Operations (vROps)** disappears from Aria Suite Lifecycle as a managed product. Lifecycle is now handled inside VCF Operations under:

**Fleet Management → Lifecycle**

---

## How did your upgrade go?

Have you upgraded to **VCF Operations** yet? Any surprises or “gotchas” I should add to the list?

Drop a comment below—or if you have questions, feel free to reach out.

— C

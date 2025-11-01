---
layout: post
title: "Aria Operations 8.18.5 — Pre-Req Upgrade Process (KB)"
categories: ["Cloud Foundation"]
tags: [aria-operations, vcf, lcm, vidm]
author: "Chris"
description: "Operations L1 runbook: vIDM ➜ LCM (Patch 5) ➜ Aria Operations 8.18.5, with pitfalls, KB references, and backout."
image: /assets/images/posts/aria-ops-8185/vRops_8.18.5_upgrade_KB.png
comments: true
---

> **Lead**  
> This runbook upgrades **Aria Operations to 8.18.5** by first updating **vIDM** and **Aria Suite Lifecycle (LCM)** during the same maintenance window. It’s written for **Operations Level 1** with exact steps, pitfalls, and backout guidance.  
{: .admonition .info}

## TL;DR
- **Order:** **vIDM ➜ LCM (8.18.0 Patch 5) ➜ Aria Operations 8.18.5**
- **Common issues:** vIDM `/db` free space, WSA/OpenSearch not starting, LCM patch extract.
- **Backout:** Revert snapshots for the component that failed (details in §5).

---

# 0. Change Overview

**Scope:** Apply **vIDM 3.3.7** cumulative patch (**CSP-102092**), patch **LCM** to **8.18.0 Patch 5**, then upgrade **Aria Operations** to **8.18.5**.

**Impact:** vIDM authentication and LCM UI may be intermittently unavailable during patching; Aria Operations will experience service restarts/rebalancing during the upgrade.

**Success Criteria:**  
- Aria Operations **About** shows **8.18.5** build.  
- **LCM → System Details** shows **PATCH5**.  
- **vIDM → System Diagnostics** green.

**Backups/Snapshots:** Non-memory snapshots of **all nodes** for each product are required at the start. Remove after **24–48 hours** of stable ops.

**Upgrade Matrix**

| Component       | From     | To                   | Why                                  |
| ---             | ---      | ---                  | ---                                   |
| vIDM            | 3.3.7    | CSP-102092 applied   | Prereq fixes and stability            |
| Aria Suite LCM  | 8.18.0   | **Patch 5**          | Required path to Aria Ops 8.18.5      |
| Aria Operations | 8.18.x   | **8.18.5**           | Target security/bugfix release        |

---

# 1. VMware Identity Manager (vIDM) 3.3.7 — Apply CSP-102092

## 1.1 Pre-checks & Prep
- Confirm vIDM cluster health; identify **primary** vs **secondary** nodes.
- Verify SSH access and check free space on **/db** (target **≥ 15–20 GB** free).
- Take **non-memory snapshots** of all vIDM nodes (Primary, Secondary-1, Secondary-2).
- All actions **orchestrated** via LCM where applicable; node-level steps as noted.

## 1.2 Verify / Grow Disk Space on `/db` (if required)

{% include kb.html id="Broadcom KB 319356" title="Increase/repair vIDM/LCM disk partitions (includes /db guidance)" url="https://knowledge.broadcom.com/external/article/319356#root1" %}

Check current usage:

```bash
df -h | grep /db

Identify disks and LVM layout:

df -h; lsscsi; lsblk; pvs; vgs; lvs

If insufficient space:

Extend the VM disk in vCenter.

Grow PV/VG/LV and filesystem (example names; adjust for your env):

pvresize /dev/sdc
lvextend -l +100%FREE /dev/db_vg/db
resize2fs /dev/db_vg/db

1.3 Stage & Apply Patch (Node by Node)

Order (sequential): Primary ➜ Secondary-1 ➜ Secondary-2 (do not patch in parallel).

# Copy CSP-102092 bundle to each node (e.g., /db/vidm-upgrade) and unzip
cd /db/vidm-upgrade/CSP-102092/
./CSP-102092-applyPatch.sh

# Monitor progress
tail -f /opt/vmware/var/log/update/vidm-CSP-102092-update.log


Allow each node to reboot automatically. Proceed to the next node only when the previous node is healthy.

1.4 Post-Patch Validation (per node)

vIDM → System Diagnostics: all green; Directory Sync OK; Auth Adapters open without error.

OpenSearch/WSA healthy; if needed:

{% include kb.html id="Broadcom KB 315176" title="VMware Identity Manager (WSA/OpenSearch) service will not start" url="https://knowledge.broadcom.com/external/article/315176
" %}

/etc/init.d/opensearch status
/etc/init.d/opensearch stop
/etc/init.d/opensearch start


Console access (if required by your SOP):

systemctl enable getty@tty1.service
systemctl start getty@tty1.service

1.5 Snapshot Policy

Retain vIDM snapshots until LCM and Aria Operations sections are complete and stable.

2. Aria Suite Lifecycle (LCM) — 8.18.0 Patch 5
2.1 Pre-checks & Prep

Confirm LCM is reachable and healthy (About/System Details).

Take a non-memory snapshot of the LCM appliance.

2.2 Stage Patch 5 Binary

Copy Patch 5 file to /data on the LCM appliance (SCP/SFTP).

LCM UI → Lifecycle Operations → Settings → Binary Mapping → Patch Binaries:

Delete stale entries if present.

Set Source Location = /data, click Discover, then Add.

2.3 Install Patch 5

{% include kb.html id="Broadcom KB 412142" title="Aria Suite Lifecycle 8.18 — Patch 5 install procedure" url="https://knowledge.broadcom.com/external/article/412142
" %}

LCM UI → Lifecycle Operations → Settings → System Patches → Install Patch.
LCM will reboot automatically on completion.

2.4 Validate LCM Patch Level

LCM → About/System Details should show:

Version 8.18.0.0

Patch Version: PATCH5

Updated Build Number

2.5 Postgres Cluster Patch (if prompted)

If LCM prompts to patch Postgres Cluster for the Global Environment, execute after vIDM + LCM patches are validated.

3. VMware Aria Operations — Upgrade to 8.18.5
3.1 Pre-checks & Prep

Confirm cluster health: green and adapters collecting.

Take non-memory snapshots of all nodes (Master, Data, Remote Collectors).

Ensure §1 (vIDM) and §2 (LCM) are complete and validated.

3.2 Stage & Map 8.18.5 Binary in LCM

Copy the Aria Operations 8.18.5 update package to /data on LCM.

LCM → Lifecycle Operations → Settings → Binary Mapping (Product/Patch Binaries) → Discover and Add the package.

3.3 Execute Upgrade from LCM

LCM → Environments → <Your Aria Operations Environment> → Upgrade.

Run Precheck and resolve warnings (disk, certs, layout).

Select 8.18.5 and start the upgrade. Nodes update sequentially and may reboot.

3.4 Post-Upgrade Validation

Aria Operations → About shows 8.18.5 (build).

Adapters/reporting healthy; dashboards render; vIDM authentication works.

Remove snapshots after 24–48 hours of stability per policy.

4. Issues & Workarounds
4.1 vIDM — Disk Space /db Insufficient

{% include kb.html id="Broadcom KB 319356" title="Increase/repair vIDM/LCM disk partitions (includes /db guidance)" url="https://knowledge.broadcom.com/external/article/319356#root1
" %}

# Inspect & grow
df -h; lsscsi; lsblk; pvs; vgs; lvs
pvresize /dev/sdc
lvextend -l +100%FREE /dev/db_vg/db
resize2fs /dev/db_vg/db


Re-run the patch once free space ≥ 15–20 GB on /db.

4.2 vIDM — WSA/OpenSearch Not Starting

{% include kb.html id="Broadcom KB 315176" title="VMware Identity Manager (WSA/OpenSearch) service will not start" url="https://knowledge.broadcom.com/external/article/315176
" %}

/etc/init.d/opensearch status
/etc/init.d/opensearch stop
/etc/init.d/opensearch start


Verify cluster primary/roles and System Diagnostics health.

4.3 LCM — Drive Space / Patch Extract Issues

{% include kb.html id="Broadcom KB 319356" title="Increase/repair LCM disk partitions (drive/partition growth guidance)" url="https://knowledge.broadcom.com/external/article/319356#root1
" %}

If the patch task seems stuck but System Details shows PATCH5, allow a full appliance reboot, verify services, then retry actions.

4.4 LCM — 8.18 Patch 5 Installation

{% include kb.html id="Broadcom KB 412142" title="Aria Suite Lifecycle 8.18 — Patch 5 install procedure" url="https://knowledge.broadcom.com/external/article/412142
" %}

Follow: upload to /data → Binary Mapping (Discover/Add) → System Patches → Install Patch.

4.5 vIDM — CSP-102092 Patch Procedure

{% include kb.html id="Broadcom KB 412021" title="vIDM 3.3.7 — CSP-102092 cumulative patch procedure" url="https://knowledge.broadcom.com/external/article/412021
" %}

5. Backout / Rollback

If a phase fails and cannot be resolved in-window:

vIDM:

Revert the last patched node snapshot first; validate services.

Revert remaining nodes only if needed.

LCM:

Revert the LCM appliance snapshot; confirm System Details post-revert.

Aria Operations:

Revert all cluster nodes’ snapshots; confirm cluster green and adapters running.

References

{% include kb.html id="Broadcom KB 319356" title="Increase/repair vIDM/LCM disk partitions (includes /db guidance)" url="https://knowledge.broadcom.com/external/article/319356#root1
" %}
{% include kb.html id="Broadcom KB 315176" title="VMware Identity Manager (WSA/OpenSearch) service will not start" url="https://knowledge.broadcom.com/external/article/315176
" %}
{% include kb.html id="Broadcom KB 412142" title="Aria Suite Lifecycle 8.18 — Patch 5 install procedure" url="https://knowledge.broadcom.com/external/article/412142
" %}
{% include kb.html id="Broadcom KB 412021" title="vIDM 3.3.7 — CSP-102092 cumulative patch procedure" url="https://knowledge.broadcom.com/external/article/412021
" %}

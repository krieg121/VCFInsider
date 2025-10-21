---
layout: post
title: "Aria Operations 8.18.5 Pre-Req Upgrade Process (KB)"
categories: ["cloud-foundation"]
tags: [aria-operations, vcf, lcm, vidm]
author: "Chris"
description: "Step-by-step pre-requisite upgrade process for Aria Operations 8.18.5."
image: /assets/images/posts/aria-ops-8185/vRops_8.18.5_upgrade_KB.png
---

![Aria Operations 8.18.5 Pre-Req Upgrade Process (KB)](/assets/images/posts/aria-ops-8185/vRops_8.18.5_upgrade_KB.png)




Operations Runbook: vIDM → Aria Suite Lifecycle (LCM) → Aria Operations 8.18.5

Audience: Level 1 Operations  |  Objective: Upgrade Aria Operations to 8.18.5 by first updating vIDM and LCM during the same maintenance window.

# 0. Change Overview

Scope: Apply vIDM 3.3.7 cumulative patch (CSP‑102092), patch Aria Suite Lifecycle to 8.18.0 Patch 5, then upgrade Aria Operations to 8.18.5.

Impact: vIDM authentication and LCM UI may be intermittently unavailable during patching; Aria Operations will have service restarts/rebalancing during upgrade.

Success Criteria: Aria Operations “About” shows 8.18.5 build; LCM System Details shows PATCH5; vIDM System Diagnostics green.

Backups/Snapshots: Non‑memory snapshots of all nodes for each product are required at the start of the window. Remove after 24–48 hours of stable operations.

# 1. VMware Identity Manager (vIDM) 3.3.7 — Patch CSP‑102092

## 1.1 Pre‑checks & Prep

Confirm vIDM cluster health and identify primary vs secondary nodes.

Confirm SSH access to each node and available disk space on /db (target ≥ 15–20 GB free).

Take non‑memory snapshots of all vIDM nodes (Primary, Secondary‑1, Secondary‑2).

Using LCM for all tasks

## 1.2 Verify / Grow Disk Space on /db (if required)

Check current usage:

df -h | grep /db

Identify disks and LVM layout:

df -h; lsscsi; lsblk; pvs; vgs; lvs

If insufficient space:
• Extend the VM disk in vCenter.
• Then run (example names; adjust to your VG/LV):

pvresize /dev/sdc
lvextend -l +100%FREE /dev/db_vg/db
resize2fs /dev/db_vg/db

## 1.3 Stage & Apply Patch (Node by Node)

Patch order (sequential): Primary → Secondary‑1 → Secondary‑2 (do NOT patch in parallel).

Copy the CSP‑102092 patch bundle to each node (e.g., /db/vidm-upgrade) and unzip it.

Run the patch script from the extracted folder (exact name per bundle):

./CSP-102092-applyPatch.sh

Monitor progress:

tail -f /opt/vmware/var/log/update/vidm-CSP-102092-update.log

Allow the node to reboot automatically on completion; proceed to the next node only after it is healthy.



Figure 1‑A — vIDM CSP‑102092 patch in progress

## 1.4 Post‑Patch Validation (per node)

vIDM → System Diagnostics: all green; Directory Sync succeeds; Auth Adapters open without error.

OpenSearch/WSA healthy; if needed:
• Check service: /etc/init.d/opensearch status
• Start/stop: /etc/init.d/opensearch {start|stop}
• Recheck node roles and cluster health per KB guidance.

Console access available (getty) if applicable:
• systemctl enable getty@tty1.service
• systemctl start getty@tty1.service

## 1.5 Snapshot Policy

Retain vIDM snapshots until LCM and Aria Operations sections complete and environment is stable.

# 2. Aria Suite Lifecycle (LCM) — 8.18.0 Patch 5

## 2.1 Pre‑checks & Prep

Confirm LCM is reachable and healthy (About/System Details).

Take a non‑memory snapshot of the LCM appliance.

## 2.2 Stage Patch 5 Binary

Copy the Patch 5 file to /data on the LCM appliance (SCP/SFTP).

In LCM UI → Lifecycle Operations → Settings → Binary Mapping → Patch Binaries:

Delete stale patch entries if present.

Set Source Location to /data, click Discover, then Add.

## 2.3 Install Patch 5

LCM UI → Lifecycle Operations → Settings → System Patches → Install Patch.

LCM will reboot automatically when patching completes.

## 2.4 Validate LCM Patch Level

LCM → About/System Details should show: Version 8.18.0.0, Patch Version: PATCH5, and an updated Build Number.



Figure 2‑A — LCM 8.18.0 Patch 5

## 2.5 Postgres Cluster Patch (if prompted)

If LCM displays a prompt to patch Postgres Cluster for the Global Environment, run it after vIDM and LCM patches are complete and validated.

# 3. VMware Aria Operations — Upgrade to 8.18.5

## 3.1 Pre‑checks & Prep

Confirm cluster health is green and adapters are collecting.

Take non‑memory snapshots of all Aria Operations nodes (Master, Data, Remote Collectors).

Verify vIDM and LCM sections are fully complete and validated.

## 3.2 Stage & Map 8.18.5 Binary in LCM

Copy the Aria Operations 8.18.5 update package to /data on the LCM appliance.

In LCM → Lifecycle Operations → Settings → Binary Mapping (Product or Patch Binaries): Discover and Add the package.

## 3.3 Execute Upgrade from LCM

LCM → Environments → <Your Aria Operations Environment> → Upgrade.

Run Precheck and resolve any warnings (disk space, certificates, cluster layout).

Select version 8.18.5 and start the upgrade. Nodes will update sequentially and may reboot.

## 3.4 Post‑Upgrade Validation

Aria Operations → About displays 8.18.5 (build).



Figure 3‑A — Aria Operations 8.18.5 (About)

Adapters/reporting healthy; dashboards render; authentication via vIDM works.

Remove snapshots after 24–48 hours of stability per change policy.

# 4. Issues & Workarounds (Use these if you hit problems)

## 4.1 vIDM — Disk Space /db Insufficient

KB: https://knowledge.broadcom.com/external/article/319356#root1

Extend VM disk in vCenter.

On the node, identify LVM layout and extend PV/VG/LV and filesystem:

df -h; lsscsi; lsblk; pvs; vgs; lvs
pvresize /dev/sdc
lvextend -l +100%FREE /dev/db_vg/db
resize2fs /dev/db_vg/db

Re‑run the patch once free space ≥ 15–20 GB on /db.

## 4.2 vIDM — WSA/OpenSearch Service Issues

KB: https://knowledge.broadcom.com/external/article/315176/vmware-identity-manager-vidm-wsa-servic.html

Check status and restart as needed across nodes:

/etc/init.d/opensearch status
/etc/init.d/opensearch stop
/etc/init.d/opensearch start

Verify cluster primary and health in System Diagnostics; review logs referenced in the KB.

## 4.3 LCM — Drive Space / Patch Extract Issues

KB: https://knowledge.broadcom.com/external/article/319356#root1  (drive/partition growth guidance).

If patch task appears stuck but System Details shows PATCH5, allow the appliance to fully reboot and verify services before retrying actions.

## 4.4 LCM — 8.18 Patch 5 Installation

KB: https://knowledge.broadcom.com/external/article/412142

Follow the runbook steps: upload to /data → Binary Mapping (Discover/Add) → System Patches → Install Patch.

## 4.5 vIDM — CSP‑102092 Patch Procedure

KB: https://knowledge.broadcom.com/external/article/412021



# 5. Backout / Rollback

If a phase fails and cannot be resolved in-window:

vIDM: Revert the last patched node snapshot first; validate services; revert remaining nodes only if needed.

LCM: Revert the LCM appliance snapshot; confirm System Details post-revert.

Aria Operations: Revert all cluster nodes’ snapshots; confirm cluster green and adapters running.

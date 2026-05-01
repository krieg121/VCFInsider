---
layout: post
title: "Breaking ELM Between Two VCF Instances to Restore a Supported Upgrade Path"
subtitle: "A field-driven walkthrough of dismantling a cross-instance ELM topology before a VCF upgrade"
date: 2026-05-01 10:00:00 -0400
author: Chris Kitchens
categories: ["Cloud Foundation"]
tags: ["VCF", "VMware Cloud Foundation", "vCenter", "Enhanced Linked Mode", "ELM", "SSO", "Upgrade", "vmdir", "CMS", "Field Notes"]
description: "A real-world VMware Cloud Foundation field note on breaking a cross-instance Enhanced Linked Mode topology."
image: "/assets/images/posts/2026-05-01-breaking-elm-between-two-vcf-instances-to-restore-a-supported-upgrade-path/hero.webp"
thumbnail: "/assets/images/posts/2026-05-01-breaking-elm-between-two-vcf-instances-to-restore-a-supported-upgrade-path/hero.webp"
og_image: "/assets/images/posts/2026-05-01-breaking-elm-between-two-vcf-instances-to-restore-a-supported-upgrade-path/hero.webp"
---

## Introduction

Most VMware Cloud Foundation upgrade blockers look like lifecycle problems—version mismatches, failed prechecks, or sequencing issues.

This one wasn’t.

The environment was fully functional. Services were healthy. No visible instability. But underneath that, two separate VCF instances were operating in a shared Enhanced Linked Mode (ELM) topology.

That became the blocker.

And it’s important to be clear: this wasn’t accidental. This was a deliberate design that had been implemented when it was supported. The issue surfaced because the platform evolved—and the design didn’t.

What followed wasn’t a patch. It was a controlled teardown of a shared SSO domain and replication topology.

## Background

Enhanced Linked Mode in VCF is often misunderstood as a UI-level feature. In reality, it creates a shared identity and replication boundary through:

- A common SSO domain
- vmdir replication agreements
- Shared global permissions and tags
- Cross-vCenter authentication dependencies

Historically, joining multiple VCF instances into the same SSO domain was supported.

That changed.

As noted in VCF 4.5 documentation, the ability to join multiple VCF instances to the same SSO domain was deprecated. That effectively makes cross-instance ELM an unsupported topology for modern upgrade paths.

In many environments I’ve worked with, this kind of design persists because it continues to function. The problem only shows up when you try to move forward.

## Real-World Scenario

The environment consisted of two sites operating as separate VCF instances:

- One site hosting multiple vCenters (management, workload, non-prod)
- Another site with its own management and workload vCenters

Despite being separate VCF instances, they were joined into a single SSO domain and linked through ELM.

From an operational standpoint, this created what’s often referred to as a **“handcuff topology.”**

Everything worked—but nothing was truly independent.

When the upgrade path to a newer VCF version was evaluated, this topology became a hard stop. The environment had to be separated before proceeding.

## Technical Analysis

This is where things get interesting.

Breaking ELM isn’t just “unlinking vCenters.” You’re dismantling a shared identity system backed by vmdir replication.

### What Actually Existed


- Multiple vCenters across two sites shared a single SSO domain
- vmdir replication agreements existed across sites
- Identity and authentication were fully coupled
- Management and workload domains were not cleanly isolated

### What Had to Change

The goal was to:

- Remove cross-site SSO dependencies
- Break replication agreements
- Restore independent VCF instance boundaries

This required working directly with:

- **CMS utilities (vCenter domain management)**
- **vmdir replication tools (`vdcrepadmin`)**
- **SSO unregister workflows**

### Execution Details

From an execution standpoint, the process followed a controlled sequence:

#### 1. Environment Preparation

- All vCenters were powered down simultaneously
- Snapshots were taken across all nodes
- DRS was set to manual to prevent movement during the process

One thing that often surprises teams:

If you snapshot a vmdir-based topology, all nodes must be treated consistently. Partial rollback creates replication divergence.

#### 2. CMS-Based Unregistration

From the primary site, the team:

- Executed `cmsso-util unregister` commands
- Removed remote vCenter nodes from the SSO domain
- Used administrator-level SSO credentials

This effectively detached one site from the shared identity domain.

#### 3. Replication Topology Rebuild

After unregistering nodes:

- `vdcrepadmin` was used to recreate replication agreements
- A new ring topology was established for the remaining nodes
- Cross-site replication agreements were removed

This step is critical.

Breaking ELM without rebuilding replication properly leaves the environment in an inconsistent state.

#### 4. Site Separation

Post-change:

- One site operated independently with its own vCenters
- The other site retained its own internal ELM structure
- Cross-instance dependencies were fully removed

This is where the architecture returned to a supported model.

## Operational Considerations

From an operations perspective, this wasn’t just a technical task—it was a coordinated change event.

### What Went Well

- Full environment snapshots before change
- Controlled shutdown of all vCenters
- GSS oversight during execution
- Clear sequencing of unregister and replication steps

### What Required Attention

A few things stood out post-change:

- Certificate references still pointed to the original site
- Additional certificate regeneration was required
- Replication topology had to be validated manually

This is typical.

Breaking ELM solves the primary problem, but secondary cleanup work is almost always required.

> **Important note:**  
> This work addressed the deprecated cross-instance ELM configuration and removed the immediate architectural blocker. That said, ELM will still need to be removed before the affected vCenters are upgraded to vCenter 9.0.

### Validation

After separation:

- All vCenters powered on successfully
- Services were verified via service-control checks
- SDDC Managers were accessible and functional
- No UI instability (no “spinning circle” issues)
- Replication topology confirmed healthy

From an operations perspective, this is the real success criteria—not just command completion.

## Lessons Learned

This scenario reinforces several patterns that show up repeatedly in VCF environments.

### 1. Functional Does Not Mean Supported

The environment was stable before the change.

That didn’t make it upgradeable.

### 2. ELM Creates Real Architectural Coupling

This wasn’t just shared visibility. It was:

- Shared identity
- Shared replication
- Shared failure domain

That coupling is what made the upgrade path invalid.

### 3. Breaking ELM Is a Multi-Layer Operation

You’re not just removing links—you’re modifying:

- SSO domain membership
- vmdir replication agreements
- Certificate relationships
- Service dependencies

Each layer needs to be addressed.

### 4. Replication Topology Matters More Than Most Realize

One thing that often surprises teams is how critical replication design is.

After unlinking:

- You must explicitly rebuild a valid topology
- Ring structures are commonly used
- Validation is not optional

### 5. Cleanup Work Is Inevitable

Even after a successful separation:

- Certificates may need regeneration
- Residual references may exist
- Additional change windows may be required

Plan for that upfront.

## Conclusion

This wasn’t a lifecycle failure. It was an architectural correction.

The upgrade blocker wasn’t a version mismatch or a failed precheck—it was a legacy topology that no longer aligned with supported VCF design.

Breaking Enhanced Linked Mode between two VCF instances required:

- Controlled shutdown and protection of all nodes
- CMS-based removal of SSO relationships
- Reconfiguration of vmdir replication
- Careful validation of platform health afterward

From an operations perspective, the takeaway is simple:

Always validate the architecture before starting an upgrade.

Because sometimes the most important step in an upgrade isn’t applying a patch.

It’s removing a dependency that shouldn’t exist anymore.
---
layout: post
title: "Distributed Power Management: The VMware Feature Most Enterprises Never Used"
subtitle: "Why DPM remains one of vSphere’s most capable — yet most overlooked — automation features."
date: 2026-03-12
author: Chris Kitchens
categories: ["Automation"]
tags: ["vSphere", "VCF", "Automation", "Power Management", "DRS"]
description: "Distributed Power Management (DPM) automatically powers hosts on and off based on demand, yet most enterprises never enabled it. Here's why—and how to make it work in modern VMware Cloud Foundation environments."
image: /assets/images/posts/2026-03-14-distributed-power-management-the-vmware-feature-most-enterprises-never-used/hero.webp
thumbnail: /assets/images/posts/2026-03-14-distributed-power-management-the-vmware-feature-most-enterprises-never-used/hero.webp
og_image: /assets/images/posts/2026-03-14-distributed-power-management-the-vmware-feature-most-enterprises-never-used/hero.webp
---

## Introduction
Distributed Power Management (DPM) has been part of vSphere since the early days, but it’s one of those features that almost no one in enterprise environments ever turned on. The idea is simple: when cluster demand drops, vSphere automatically powers down idle hosts, and when load increases, it brings them back online. On paper, it’s a perfect blend of automation and energy efficiency.

In practice, most enterprise clusters have never used it. Many admins have heard of DPM, maybe even tested it in a lab, but few have trusted it in production. That’s unfortunate—because when properly configured, DPM works remarkably well. It’s not a broken feature; it’s a forgotten one.

## Background
At its core, DPM extends what Distributed Resource Scheduler (DRS) already does. DRS balances workloads across hosts based on resource demand. DPM adds the ability to remove hosts from the pool entirely when they’re not needed and bring them back when they are.

Here’s the basic flow:

DRS evaluates cluster load and determines that existing hosts have excess capacity.

DPM decides that one or more hosts can be safely placed in standby.

vCenter issues a power command through the host’s Baseboard Management Controller (BMC)—using IPMI, iLO, iDRAC, or Redfish—to power it off.

When demand rises, DPM wakes the host through the same interface and reintegrates it into the cluster.

In VMware Cloud Foundation (VCF), the behavior is the same. Each Workload Domain runs its own vCenter and DRS cluster, so DPM operates locally within that domain. The logic is identical whether you’re managing a single vSphere cluster or a VCF-managed environment.

## Real-World Scenario
Earlier in my career I worked for a company that had roughly 250 employees. Our server room was local, not a vast datacenter and Cloud wasn't even a thing yet. Power consumption and cooling costs were a real concern. of ESXi hosts running at 10–20% utilization overnight. Our team was tasked to see if we could find a way to cut costs. I suggested DPM. I was given the OK to test it on NP. After enabling and configuring the test cluster, I let it run for awhile. Eventually it powered down 2 hosts in a 5 node cluster (You can control how many hosts it will power down). You can use BMC software to wake up the servers, but you can also use WOL nics. If I remember correctly, your BMC nic needs to be WOL enabled if you go this route.

I spent a week testing the cluster, running servers hot to see if it would power on hosts when needed. It did. I pulled the plug on a server to see what would happen. It powered up a host, and HA'd the VMs over to it and powered them on. In short, it was solid. I was impressed to say the least. I then implemented it in non-prod. Let it run for a month or two, then prod. Mind you, I didn't enable this on EVERY cluster we had. I don't remember how much $$$ we ended up saving (this was back in 2009) but I do remember it definitely helped. I think our team got some Jimmy Johns out of it (I hate JJs).


## Technical Analysis
From a technical standpoint, DPM relies on several moving parts working together:

vCenter Server: Runs the DRS and DPM logic, evaluating resource demand and issuing power commands.

ESXi Host Agents (hostd/vpxa): Handle standby and wake operations when directed by vCenter.

BMC Interfaces (iLO, iDRAC, IPMI, Redfish): Provide out-of-band power control.
or
WOL Nics

DRS Scheduler: Ensures no powered-off host is holding critical workloads before shutdown.

In a healthy environment, the sequence looks like this:

DRS detects low utilization and recommends putting specific hosts in standby.

vCenter vMotions all active VMs off those hosts.

vCenter sends a power-off command via the BMC interface.

When cluster demand increases, DRS requests additional capacity.

DPM issues a power-on command, waits for the host to rejoin vCenter, and rebalances workloads.

Latency between the power-on event and host readiness depends mostly on hardware and firmware. Modern Redfish-based controllers are much faster than older IPMI implementations. Just keep in mind, HA restart times may be longer due to the boot up.

## Operational Considerations
So why isn’t everyone using DPM? 
1. In my experience, I have heard "We pay a flat rate for our power so this wouldn't save us any $$$" "If a server is powered down, someone may take it" (LOL) I could go on, but it basically boils down to trust.

2. Fear of automation: Many admins are uncomfortable letting vCenter power-cycle physical hardware automatically.

3. Mixed hardware: DPM works best when all hosts have identical firmware, BIOS settings, and BMC interfaces. Mixed generations often behave inconsistently.

4. Power-on latency: If a host takes several minutes to boot, DPM may lag behind sudden demand spikes.

5. Historical firmware issues: Early IPMI and BMC bugs caused occasional failures to wake hosts, leaving clusters short on capacity.

## Environmental Factors
Power and cooling behavior vary widely between data centers. In some facilities, idle hosts still draw significant baseline power, reducing the benefit of DPM. In others—especially where energy costs or thermal limits are tight—the savings can be substantial.

## Integration and Monitoring
DPM actions appear in vCenter events and can be tracked in Aria Operations. 

It’s good practice to monitor:

Number of hosts in standby

Average power-on duration

Cluster resource headroom before DPM triggers

Any failed power-on or power-off attempts

## Where DPM Shines
DPM isn’t for every cluster—but it’s perfect for some.

Dev/Test Clusters: Idle capacity overnight can be safely powered down without impacting SLAs.

Lab Environments: Ideal for transient workloads and experimentation.

VDI Clusters: Predictable daily demand cycles make host power management easy to tune.

Edge Deployments: When every watt matters, automated host control helps stay within power budgets.

Sustainability-Focused Operations: DPM directly supports measurable energy efficiency goals.

## Lessons Learned
A few patterns emerge from real-world usage:

Consistency is key. Identical hardware and firmware eliminate most DPM issues.

Test before production. Validate in a non-critical cluster to measure wake latency and reliability.

Integrate with monitoring. Visibility builds confidence—knowing when and why hosts power off helps teams trust automation.

DPM and HA coexist fine. vSphere HA respects powered-off hosts and won’t place workloads there until DPM brings them online.

Once tuned, DPM becomes nearly invisible. The cluster quietly scales itself up and down, saving power without manual intervention.

## Conclusion
Distributed Power Management is one of those features that quietly matured while the industry moved on to other automation topics. It’s stable, effective, and fully supported in modern vSphere and VCF releases. Yet, most enterprises still leave it disabled.

If your clusters have predictable load patterns or idle capacity, it’s worth revisiting. Start small, validate hardware compatibility, and monitor results. You might be surprised how well it works and how much $$$ you save.

DPM isn’t a broken feature. It’s a forgotten one. And imo, it’s time to remember it.

-Chris
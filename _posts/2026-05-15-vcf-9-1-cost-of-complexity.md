---
layout: post
title: "VCF 9.1 and the Cost of Complexity: When Unified Operations Stops Feeling Unified"
subtitle: "There is a difference between simplifying consumption and simplifying the infrastructure required to make it work."
date: 2026-05-15 09:00:00 -0400
author: "Chris Kitchens"
categories: ["Opinion"]
tags:
  - VCF 9.1
  - VCF Operations
  - VMware Cloud Foundation
  - Broadcom
  - VCF Management Services
  - VCF License Server
  - Home Lab
  - vExpert
description: "VCF 9.1 may simplify the platform experience at enterprise scale, but the growing management-plane footprint raises real questions for practitioners, home labs, vExperts, and anyone trying to learn the platform hands-on."
image: "/assets/images/posts/2026-05-15-vcf-9-1-cost-of-complexity/hero.webp"
thumbnail: "/assets/images/posts/2026-05-15-vcf-9-1-cost-of-complexity/hero.webp"
og_image: "/assets/images/posts/2026-05-15-vcf-9-1-cost-of-complexity/hero.webp"
---

When VMware Cloud Foundation 9.0 was introduced, the message felt pretty clear: VCF Operations was becoming the centralized operational experience for the platform.

For those of us who have worked with separate products like Aria Operations, Aria Operations for Logs, Aria Operations for Networks, Aria Automation, Lifecycle Manager, SDDC Manager, and traditional license management workflows, that direction made sense. VCF was being pulled together into something more unified. At least, that was the way many of us interpreted the message.

Then VCF 9.1 arrived, and the story started to feel a little less clear.

VCF Operations may still be the front door, but more of the backend platform appears to be moving into required supporting services: VCF Management Services, Services Runtime, Identity Broker, License Server, fleet and instance components, real-time metrics, telemetry, software depot functions, and additional DNS/IP planning.

Architecturally, that may make sense.

Operationally, especially from the practitioner and lab side, it feels like the platform is becoming heavier at the same time it is being marketed as more unified.

## The Difference Between Consumption and Deployment

There is a difference between simplifying consumption and simplifying the infrastructure required to make it work.

That distinction matters.

Broadcom's VCF 9.1 messaging focuses heavily on enterprise-scale outcomes: better infrastructure efficiency, memory tiering, faster upgrades, fleet capacity, Kubernetes operations, and lower cost per workload. Those may be valid enterprise benefits. In large environments, a more modular management architecture may be the right long-term direction.

But that does not automatically mean the platform is simpler to deploy.

It also does not mean the management-plane footprint is smaller.

That is the part I think a lot of practitioners are trying to reconcile.

VCF may be getting easier to consume at scale, but that does not necessarily mean it is getting easier to build, lab, or understand.

## VCF 9.0 Made the Direction Feel Clear

One of the things I actually liked about the VCF 9.0 direction was the idea of a more unified management experience.

Instead of dealing with a collection of standalone products and partially connected workflows, VCF Operations appeared to be positioned as the central operational plane for the platform. Monitoring, logs, network visibility, automation, fleet management, and license management all seemed to be moving under a more consistent VCF Operations umbrella.

From a field perspective, that was a good story.

Was it a big change? Absolutely.

Was it going to take time for teams to adjust? Of course.

But the direction made sense: reduce product sprawl, reduce disconnected workflows, and create a more consistent private cloud operating model.

That was the promise many of us heard.

## VCF 9.1 Complicates That Story

With VCF 9.1, the message feels more complicated.

The introduction of the VCF License Server is a good example. Broadcom documentation describes the VCF License Server as a new headless appliance introduced in version 9.1 that offloads license logic from VCF Operations and provides centralized license management on a protected appliance within the environment.

By itself, that may not be a huge issue.

The license server is not really the part that bothers me.

The bigger concern is what it represents.

If VCF Operations was supposed to become the centralized place to manage VCF licensing, why does the very next release introduce a separate license server as part of the required architecture?

Maybe the answer is that VCF Operations remains the administrator-facing management experience, while the actual licensing logic and storage are being separated into a backend service. That is a reasonable technical explanation.

But from the field, that distinction has not been communicated clearly enough.

The result is confusion.

VCF 9.0 seemed to say:

> VCF Operations is where you manage the platform.

VCF 9.1 now seems to say:

> VCF Operations is still central, but the platform also requires additional backend services to make that centralized experience work.

Those two things can both be true, but they are not the same message.

## The Management Services Footprint Is the Real Conversation

The VCF License Server is only one piece of the larger discussion.

The broader VCF Management Services and Services Runtime model is where the deployment story starts to feel much heavier. Broadcom's deployment documentation and community discussions around VCF 9.1 reference additional requirements around the VCF services runtime, fleet component, instance component, Identity Broker, and license server.

That means more planning.

More FQDNs.

More IP addresses.

More DNS work.

More infrastructure.

More moving parts.

Again, maybe this is the right architecture direction for a large enterprise private cloud platform. A modular backend may improve scalability, lifecycle management, service ownership, and future extensibility.

But if that is the direction, the message needs to be clearer.

A unified product experience is not the same thing as a simplified operational footprint.

## The Practitioner and Home Lab Problem

I fully understand that VCF is an enterprise platform.

It is not designed around a home lab. I get that.

But VMware's ecosystem has always been stronger because engineers could lab the product, break it, fix it, learn it, document it, and share real-world lessons with the community.

That matters.

I recently invested in hardware for my own VCF lab, passed the VCP-VCF Administrator exam, and started building a practical environment specifically to learn, validate, and write about the platform from a field perspective.

That kind of work is not just a hobby.

It is how many of us learn.

It is how we prepare for real customer environments.

It is how we validate upgrade paths.

It is how we find the weird issues that do not always show up in clean reference architectures.

It is how we help other engineers understand the platform.

So when the management-plane footprint grows significantly between releases, it raises a fair question:

How are independent engineers, VMUG users, vExperts, bloggers, certification candidates, and smaller lab environments supposed to keep up?

That is not meant as a dramatic statement. It is a practical one.

If experienced VMware engineers struggle to build a reasonable VCF 9.1 lab because of the required footprint, then the barrier to learning the platform gets higher.

And when the barrier to learning gets higher, the ecosystem gets weaker.

## This Is Not Just a Home Lab Complaint

It would be easy to dismiss this as a home lab problem.

I do not think that is fair.

Home labs, community labs, VMUG Advantage environments, vExpert projects, and independent blogs have always been part of the VMware learning ecosystem. They are not the same as enterprise production environments, but they influence enterprise readiness more than people sometimes admit.

The engineers building these labs are often the same engineers who later design, operate, troubleshoot, and explain the platform inside real companies.

If they cannot reasonably learn the product, that eventually affects adoption.

It affects confidence.

It affects troubleshooting depth.

It affects the quality of community content.

It affects how quickly the field can absorb major platform changes.

That is why the deployment footprint matters.

## What I Think Is Actually Happening

My best guess is that VCF Operations is still intended to be the primary management interface, while the underlying platform services are being separated into a more modular backend architecture.

In other words:

VCF Operations is the front door.

The backend services provide the platform functions underneath it.

That may be the right long-term direction. It could make VCF more scalable, more cloud-like, and easier to evolve over time. It may also help Broadcom standardize how identity, licensing, fleet services, telemetry, metrics, automation, and lifecycle functions operate across VCF environments.

But if that is the architecture direction, it needs to be explained plainly.

Because right now, the field message feels like this:

VCF is being simplified.

But the deployment requirements are expanding.

VCF Operations is central.

But more required backend services are being added.

The platform is unified.

But the infrastructure required to run that unified platform is becoming more complex.

That is the contradiction practitioners are reacting to.

## Broadcom Needs a Clearer Lab and Evaluation Story

Broadcom does not need to make VCF a tiny product.

That is not realistic.

VCF is a full-stack private cloud platform. It includes compute, storage, networking, lifecycle, operations, automation, licensing, identity, Kubernetes, and more. No one should expect that to run like a lightweight appliance.

But there needs to be a clearer story for evaluation, learning, and community enablement.

If VCF 9.1 is going to require a much heavier management-services footprint, then practitioners need honest guidance around what is truly required, what can be deferred, what is optional, what is mandatory, and what a realistic lab design looks like.

A smaller evaluation footprint, a clearly documented lab profile, or better guidance for VMUG/vExpert/certification use cases would go a long way.

Because right now, the message feels inconsistent.

VCF 9.1 may simplify the platform experience for large enterprises, but the deployment story is getting harder to ignore.

## Final Thoughts

I am not against the direction of VCF becoming more modular.

I am not against VCF Operations being the central experience.

I am not even against backend services being separated if that is what the platform needs to scale properly.

But the distinction needs to be communicated clearly.

There is a difference between simplifying consumption and simplifying the infrastructure required to make it work.

VCF 9.1 may be easier to consume at enterprise scale, but that does not automatically mean it is easier to deploy, lab, or understand.

And if VCF becomes too difficult for independent engineers to run, test, and explain, the ecosystem gets weaker.

The people writing blogs, building labs, answering community questions, validating upgrade paths, and teaching others are part of what made VMware successful in the first place.

VCF 9.1 may be the right architecture direction for enterprise private cloud.

But Broadcom needs to make sure the people trying to learn it, lab it, and advocate for it are not left behind.

## References

- [VMware Cloud Foundation 9.1 Release Notes](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-1/release-notes/vmware-cloud-foundation-9-1-0-0-release-notes.html)
- [Deploy VCF Management Services and License Server as Part of Upgrade to 9.1](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/deploy-vcf-management-services.html)
- [VCF Components FQDNs and IP Addresses](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-service-administration-and-development/9-1/vcf-components-fqdns-and-ip-addresses.html)
- [Broadcom Announces VMware Cloud Foundation 9.1](https://news.broadcom.com/releases/broadcom-announces-vmware-cloud-foundation-9-1)
- [VMware vSphere Foundation 9.1 Frequently Asked Questions](https://www.vmware.com/docs/vmware-vsphere-foundation-faqs)

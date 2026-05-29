---
layout: post
title: "SRM, vSphere Replication, and VLR: Untangling the 9.0.4 Upgrade Path"
subtitle: "Field notes from a real-world VMware Live Recovery convergence."
date: 2026-05-29 09:00:00 -0400
author: Chris Kitchens
categories: ["Cloud Foundation"]
tags: ["VMware Live Recovery", "Site Recovery Manager", "vSphere Replication", "SRM", "VLR", "Disaster Recovery", "VCF", "Upgrade", "Convergence"]
description: "Field notes from converging Site Recovery Manager and vSphere Replication into VMware Live Recovery 9.0.4, including naming confusion, build numbers, ISO/OVF media, certificates, and post-convergence plugin validation."
image: "/assets/images/posts/2026-05-29-srm-vsphere-replication-and-vlr-untangling-the-9-0-4-upgrade-path/hero.webp"
thumbnail: "/assets/images/posts/2026-05-29-srm-vsphere-replication-and-vlr-untangling-the-9-0-4-upgrade-path/hero.webp"
og_image: "/assets/images/posts/2026-05-29-srm-vsphere-replication-and-vlr-untangling-the-9-0-4-upgrade-path/hero.webp"
---

Some upgrades are difficult because the technology is complicated.

Others are difficult because the path is not as obvious as it should be.

My recent VMware Live Recovery 9.0.4 convergence landed in that second category. Once the process clicked, the upgrade path made sense: stage Site Recovery Manager and vSphere Replication to the required 9.0.2.2 baseline, deploy the new VMware Live Recovery appliance, and converge the legacy appliances into the new model.

The confusing part was getting there.

The product names changed. The version strings did not tell the whole story. The build numbers mattered more than the UI labels. The documentation referenced appliance deployment media, but the download showed up as an ISO. And after convergence, the real validation was not just whether the appliance deployed. It was whether the vCenter plugin, replication path, pairing, certificates, and recovery objects all behaved from both sides.

This is not meant to be a click-by-click runbook. It is a field note from the upgrade path: what confused me, what broke, and what I would check first next time.

## The naming is half the battle

The first source of confusion was the naming.

In the environment, the legacy components were still familiar:

| Name used here | Meaning |
|---|---|
| SRM | Site Recovery Manager, the legacy recovery orchestration appliance |
| VR | vSphere Replication, the legacy replication appliance |
| VLR | VMware Live Recovery, the newer combined appliance model |

Broadcom documentation may refer to Site Recovery Manager as VMware Live Site Recovery, while VMware Live Recovery is the newer appliance model used for the combined recovery appliance path. That is not just a branding issue. It affects how you read the documentation, identify downloads, validate versions, and explain the work to another team.

Before starting, I would make the terminology explicit:

<div class="vlr-term-card" style="margin: 1.5rem 0; padding: 1.25rem 1.5rem; border-radius: 16px; background: #f7fbff; border: 1px solid #d8e9f7; box-shadow: 0 8px 22px rgba(0, 40, 86, 0.06);">
  <div style="font-size: 0.8rem; font-weight: 700; color: #002856; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 0.75rem;">Terminology Used in This Article</div>
  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 0.75rem;">
    <div style="padding: 0.85rem 1rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #0077c8;"><strong style="color: #002856;">SRM</strong><br><span style="color: #333333;">Legacy Site Recovery Manager appliance</span></div>
    <div style="padding: 0.85rem 1rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #00a6a6;"><strong style="color: #002856;">VR</strong><br><span style="color: #333333;">Legacy vSphere Replication appliance</span></div>
    <div style="padding: 0.85rem 1rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #6f42c1;"><strong style="color: #002856;">VLR</strong><br><span style="color: #333333;">New VMware Live Recovery appliance</span></div>
  </div>
</div>

Simple, but it helps.

## Build numbers matter more than version strings

The next issue was version clarity.

The UI may still show `9.0.2`, but that does not necessarily tell the whole story. For this upgrade path, the build number is what I would validate.

| Component | Required pre-convergence build | Operational meaning |
|---|---:|---|
| vSphere Replication | 24628359 | vSphere Replication 9.0.2.2 |
| Site Recovery Manager / Live Site Recovery | 24639343 | SRM / VLSR 9.0.2.2 |
| VMware Live Recovery appliance | 24963726 | VMware Live Recovery 9.0.4 |

This became important because not every `9.0.2` appliance was equal. One vSphere Replication appliance may be at the correct 9.0.2.2 build, while another appliance still reports 9.0.2 but sits at an older build and still needs to be patched.

The lesson: do not stop at the version string. Inventory every SRM and vSphere Replication appliance and validate the build numbers before moving forward.

## 9.0.4 is not a normal in-place update

The biggest conceptual shift was realizing that this was not a traditional “mount ISO, click update, reboot” upgrade of the existing SRM and vSphere Replication appliances.

For this path, the move to VMware Live Recovery 9.0.4 is a convergence:

<div class="vlr-convergence-visual" role="img" aria-label="SRM 9.0.2.2 and vSphere Replication 9.0.2.2 converge into a new VMware Live Recovery 9.0.4 appliance" style="margin: 2rem 0; padding: 1.25rem; border-radius: 22px; background: linear-gradient(135deg, #f8fbff 0%, #eef7ff 52%, #f7fffd 100%); border: 1px solid #d7e8f7; box-shadow: 0 14px 34px rgba(0, 40, 86, 0.10); overflow-x: auto;">
  <svg viewBox="0 0 940 390" style="display:block; width:100%; max-width:940px; height:auto; margin:0 auto; font-family: Arial, Helvetica, sans-serif;">
    <defs>
      <linearGradient id="legacyBlue" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="#e9f5ff"/>
        <stop offset="100%" stop-color="#ffffff"/>
      </linearGradient>
      <linearGradient id="targetBlue" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="#ffffff"/>
        <stop offset="100%" stop-color="#e7fbfb"/>
      </linearGradient>
      <linearGradient id="arrowGrad" x1="0" y1="0" x2="1" y2="0">
        <stop offset="0%" stop-color="#0077c8"/>
        <stop offset="100%" stop-color="#00a6a6"/>
      </linearGradient>
      <filter id="softShadow" x="-20%" y="-25%" width="140%" height="150%">
        <feDropShadow dx="0" dy="10" stdDeviation="10" flood-color="#002856" flood-opacity="0.14"/>
      </filter>
      <marker id="arrowHead" markerWidth="12" markerHeight="12" refX="10" refY="6" orient="auto">
        <path d="M 0 0 L 12 6 L 0 12 z" fill="#00a6a6"/>
      </marker>
    </defs>

    <text x="470" y="36" text-anchor="middle" font-size="20" font-weight="700" fill="#002856">9.0.4 is a convergence workflow</text>
    <text x="470" y="63" text-anchor="middle" font-size="13" fill="#405466">Update the legacy appliances to the required baseline, then converge into the new appliance model.</text>

    <!-- Legacy baseline group -->
    <rect x="55" y="105" width="260" height="86" rx="16" fill="url(#legacyBlue)" stroke="#cfe2f3" filter="url(#softShadow)"/>
    <rect x="55" y="105" width="260" height="7" rx="3.5" fill="#0077c8"/>
    <text x="185" y="139" text-anchor="middle" font-size="18" font-weight="700" fill="#002856">Site Recovery Manager</text>
    <text x="185" y="165" text-anchor="middle" font-size="24" font-weight="800" fill="#0077c8">9.0.2.2</text>
    <text x="185" y="184" text-anchor="middle" font-size="12" fill="#5c6b77">required baseline</text>

    <rect x="55" y="220" width="260" height="86" rx="16" fill="url(#legacyBlue)" stroke="#cfe2f3" filter="url(#softShadow)"/>
    <rect x="55" y="220" width="260" height="7" rx="3.5" fill="#00a6a6"/>
    <text x="185" y="254" text-anchor="middle" font-size="18" font-weight="700" fill="#002856">vSphere Replication</text>
    <text x="185" y="280" text-anchor="middle" font-size="24" font-weight="800" fill="#0077c8">9.0.2.2</text>
    <text x="185" y="299" text-anchor="middle" font-size="12" fill="#5c6b77">required baseline</text>

    <!-- Convergence arrows -->
    <path d="M 325 148 C 415 148, 440 192, 525 192" fill="none" stroke="url(#arrowGrad)" stroke-width="10" stroke-linecap="round" marker-end="url(#arrowHead)"/>
    <path d="M 325 263 C 415 263, 440 218, 525 218" fill="none" stroke="url(#arrowGrad)" stroke-width="10" stroke-linecap="round" marker-end="url(#arrowHead)"/>

    <circle cx="455" cy="205" r="34" fill="#ffffff" stroke="#cfe2f3" stroke-width="2" filter="url(#softShadow)"/>
    <text x="455" y="199" text-anchor="middle" font-size="12" font-weight="700" fill="#0077c8">CONVERGE</text>
    <text x="455" y="216" text-anchor="middle" font-size="11" fill="#5c6b77">not in-place</text>

    <!-- Target appliance -->
    <rect x="585" y="120" width="300" height="170" rx="22" fill="url(#targetBlue)" stroke="#bfe8e8" filter="url(#softShadow)"/>
    <rect x="585" y="120" width="300" height="9" rx="4.5" fill="#00a6a6"/>
    <rect x="625" y="154" width="70" height="70" rx="14" fill="#0a5ea8" opacity="0.95"/>
    <text x="660" y="198" text-anchor="middle" font-size="24" font-weight="800" fill="#ffffff">VLR</text>
    <text x="746" y="176" text-anchor="middle" font-size="22" font-weight="800" fill="#002856">VMware Live Recovery</text>
    <text x="746" y="211" text-anchor="middle" font-size="38" font-weight="800" fill="#0077c8">9.0.4</text>
    <text x="746" y="239" text-anchor="middle" font-size="15" fill="#405466">new appliance model</text>
    <text x="746" y="267" text-anchor="middle" font-size="13" fill="#5c6b77">deployed separately, then converged</text>

    <rect x="94" y="335" width="752" height="32" rx="16" fill="#ffffff" stroke="#d7e8f7"/>
    <text x="470" y="356" text-anchor="middle" font-size="13" fill="#405466">Do not mount the 9.0.4 media to the old SRM/VR appliances as a normal in-place update.</text>
  </svg>
</div>

The legacy SRM and VR appliances must first be updated to the required 9.0.2.2 baseline. After that, a new VMware Live Recovery appliance is deployed and the legacy appliances are converged into it.

That distinction matters. If you approach VLR 9.0.4 like a normal in-place update of the older SRM/VR appliances, you are starting down the wrong path.

## The ISO/OVF surprise

This was one of the more annoying field discoveries.

The documentation referenced deploying the new appliance using OVA/OVF-style deployment media. In the download portal, the obvious item presented as an ISO.

The key detail was that the deployable appliance files were inside the ISO.

That may be obvious after the fact, but it was not obvious during prep. If a KB says to deploy an appliance using OVA/OVF media and the portal only appears to show an ISO, it is easy to assume you are missing an entitlement or looking in the wrong product area.

The practical field note is this:

> Do not mount the VLR 9.0.4 ISO to the old SRM or vSphere Replication appliances as an in-place update. Use the ISO to access the deployable appliance files, deploy a new VLR appliance, then run the convergence workflow.

That one sentence would have saved time.

## One VLR appliance per site/vCenter

Another point worth making clear: treat the VLR appliance placement like the old SRM model.

For a typical two-site design, each site gets its own VLR appliance, and each VLR appliance is registered or associated with the local vCenter for that site.

<div class="vlr-site-pairing" role="img" aria-label="Two-site VLR model showing each vCenter vertically aligned to its local VLR appliance, with Site Pairing between VLR appliances" style="margin: 1.9rem 0; padding: 1.5rem; border-radius: 18px; background: linear-gradient(135deg, #f8fbff 0%, #eef7ff 100%); border: 1px solid #d8e9f7; box-shadow: 0 10px 26px rgba(0, 40, 86, 0.08);">

  <div style="font-size: 0.78rem; font-weight: 800; color: #0077c8; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 0.45rem;">Two-Site VLR Model</div>
  <div style="font-size: 1.1rem; font-weight: 800; color: #002856; margin-bottom: 1rem;">One VLR appliance per site / vCenter</div>

  <div style="display: grid; grid-template-columns: minmax(220px, 1fr) auto minmax(220px, 1fr); gap: 1rem; align-items: center;">

    <div style="padding: 1rem; border-radius: 16px; background: #ffffff; border: 1px solid #d7e8f7; box-shadow: 0 5px 16px rgba(0, 40, 86, 0.06);">
      <div style="font-size: 0.78rem; font-weight: 800; color: #0077c8; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 0.75rem;">Site A</div>

      <div style="padding: 0.95rem; border-radius: 12px; background: #f9fcff; border-left: 5px solid #0077c8;">
        <div style="font-weight: 800; color: #002856;">vCenter</div>
        <div style="font-size: 0.9rem; color: #333333; margin-top: 0.2rem;">Local site registration</div>
      </div>

      <div style="text-align: center; color: #0077c8; font-size: 1.7rem; font-weight: 800; line-height: 1.2; margin: 0.35rem 0;">↓</div>

      <div style="padding: 0.95rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #00a6a6; box-shadow: 0 4px 12px rgba(0, 40, 86, 0.05);">
        <div style="font-weight: 800; color: #002856;">VLR Appliance</div>
        <div style="font-size: 0.9rem; color: #333333; margin-top: 0.2rem;">One appliance for Site A</div>
      </div>
    </div>

    <div style="text-align: center;">
      <div style="font-size: 1.6rem; color: #7b8794; font-weight: 900; line-height: 1;">⇄</div>
      <div style="margin-top: 0.45rem; padding: 0.55rem 0.75rem; border-radius: 999px; background: #ffffff; border: 1px solid #d7e8f7; color: #002856; font-weight: 800; white-space: nowrap;">Site Pairing</div>
    </div>

    <div style="padding: 1rem; border-radius: 16px; background: #ffffff; border: 1px solid #d7e8f7; box-shadow: 0 5px 16px rgba(0, 40, 86, 0.06);">
      <div style="font-size: 0.78rem; font-weight: 800; color: #00a6a6; text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 0.75rem;">Site B</div>

      <div style="padding: 0.95rem; border-radius: 12px; background: #f9fcff; border-left: 5px solid #0077c8;">
        <div style="font-weight: 800; color: #002856;">vCenter</div>
        <div style="font-size: 0.9rem; color: #333333; margin-top: 0.2rem;">Local site registration</div>
      </div>

      <div style="text-align: center; color: #00a6a6; font-size: 1.7rem; font-weight: 800; line-height: 1.2; margin: 0.35rem 0;">↓</div>

      <div style="padding: 0.95rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #00a6a6; box-shadow: 0 4px 12px rgba(0, 40, 86, 0.05);">
        <div style="font-weight: 800; color: #002856;">VLR Appliance</div>
        <div style="font-size: 0.9rem; color: #333333; margin-top: 0.2rem;">One appliance for Site B</div>
      </div>
    </div>
  </div>

  <div style="margin-top: 1rem; padding: 0.9rem 1rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #0077c8; color: #333333; line-height: 1.5;">
    <strong style="color: #002856;">Key point:</strong> deploy and register one VLR appliance per site/vCenter, then establish <strong>Site Pairing</strong> between the two sites.
  </div>
</div>

Do not assume one VLR appliance covers both sides of the recovery pair. The appliance belongs to the site/vCenter it is deployed for, and the recovery relationship is established through the supported workflow.

## Time, DNS, and certificates all have to agree

This was one of the biggest troubleshooting lessons.

During the process, I hit a SAML-style authentication failure that looked roughly like this:

<div class="vcfi-field-note" style="margin: 1.75rem 0; padding: 1.4rem; border-radius: 18px; background: linear-gradient(135deg, #fffdf8 0%, #f7fbff 100%); border: 1px solid #d7e8f7; border-left: 6px solid #0077c8; box-shadow: 0 10px 26px rgba(0, 40, 86, 0.08);">
  <div style="font-size: 0.78rem; font-weight: 800; color: #0077c8; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 0.65rem;">Field Note</div>
  <div style="font-size: 1.15rem; font-weight: 800; color: #002856; margin-bottom: 0.75rem;">Identity and trust matter</div>
  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.8rem; margin: 0.9rem 0;">
    <div style="padding: 0.9rem; border-radius: 12px; background: #ffffff; border-top: 4px solid #0077c8; box-shadow: 0 4px 14px rgba(0, 40, 86, 0.05);">
      <div style="font-weight: 800; color: #002856; margin-bottom: 0.25rem;">Time / NTP</div>
      <div style="font-size: 0.92rem; color: #333333; line-height: 1.45;">SAML authentication is time-sensitive.</div>
    </div>
    <div style="padding: 0.9rem; border-radius: 12px; background: #ffffff; border-top: 4px solid #00a6a6; box-shadow: 0 4px 14px rgba(0, 40, 86, 0.05);">
      <div style="font-weight: 800; color: #002856; margin-bottom: 0.25rem;">DNS / FQDN</div>
      <div style="font-size: 0.92rem; color: #333333; line-height: 1.45;">Names need to resolve consistently.</div>
    </div>
    <div style="padding: 0.9rem; border-radius: 12px; background: #ffffff; border-top: 4px solid #4a6cf7; box-shadow: 0 4px 14px rgba(0, 40, 86, 0.05);">
      <div style="font-weight: 800; color: #002856; margin-bottom: 0.25rem;">Certificate CN/SAN</div>
      <div style="font-size: 0.92rem; color: #333333; line-height: 1.45;">Use the appliance FQDN, not short name or IP.</div>
    </div>
  </div>
  <div style="margin-top: 0.9rem; padding: 0.85rem 1rem; border-radius: 12px; background: #ffffff; border: 1px solid #d7e8f7; color: #333333; line-height: 1.5;">
    <strong style="color: #002856;">Lesson:</strong> Do not validate only that <code>:5480</code> works. Also validate that vCenter can trust and load the plugin using the appliance FQDN.
  </div>
</div>

The root cause of the authentication failure was time-related. The appliance time was off. Once time/NTP was corrected, the admin UI and authentication path started behaving again.

That made sense. SAML is time-sensitive. If vCenter, SSO, SRM, VR, or VLR appliances disagree on time, authentication can fail in ways that look much more complicated than they really are.

But time was not the only identity issue.

I also had to correct the appliance certificate identity so the certificate subject used the FQDN instead of a short name. After that, additional plugin-access issues improved.

That is the bigger lesson:

> The plugin path is sensitive to identity. Time, DNS, FQDN, and certificate subject information all need to line up.

If the VLR appliance is reachable at `:5480`, that only proves the appliance management interface is reachable. It does not prove the vCenter plugin path is healthy. The vCenter plugin still depends on registration, extension metadata, certificate trust, browser/session behavior, and service health.

Before blaming the plugin, I would check:

- Is appliance time synchronized with vCenter/SSO?
- Does the VLR FQDN resolve correctly?
- Does the certificate use the FQDN rather than a short name or IP?
- Is vCenter being accessed by FQDN?
- Do the vCenter extension registrations point to the expected VLR appliance?
- Has the vSphere Client service or browser session been refreshed after registration/certificate changes?

This was one of those issues where everything looked “mostly right” until vCenter tried to load the plugin. That is where the short-name certificate started to matter.

## Post-convergence validation is not optional

After convergence, I would not call the change complete just because the appliance deployed and the workflow finished.

The validation needs to happen from the vCenter plugin path, not only the appliance admin page.

At minimum, I would validate:

- VLR appliance admin UI loads at `https://<vlr-fqdn>:5480`
- VLR is registered to the correct local vCenter
- vCenter Site Recovery / VLR plugin loads
- vSphere Replication shows healthy
- VMware Live Site Recovery / recovery services show healthy
- Site pairing is connected
- Replications are visible
- Protection groups are visible
- Recovery plans are visible
- A non-disruptive test or replication validation succeeds

I saw cases where the local site looked healthy while the remote site still showed inaccessible. That is exactly why both sides need to be validated before declaring victory.

## When the plugin does not load

One of the more frustrating failure modes was this:

<div class="vcfi-troubleshooting-card" style="margin: 1.75rem 0; padding: 1.4rem; border-radius: 18px; background: linear-gradient(135deg, #f8fbff 0%, #eef7ff 100%); border: 1px solid #d7e8f7; box-shadow: 0 10px 26px rgba(0, 40, 86, 0.08);">
  <div style="font-size: 0.78rem; font-weight: 800; color: #0077c8; text-transform: uppercase; letter-spacing: 0.08em; margin-bottom: 0.65rem;">Troubleshooting Pattern</div>
  <div style="font-size: 1.15rem; font-weight: 800; color: #002856; margin-bottom: 1rem;">Admin UI works, but the vCenter plugin does not</div>

  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 0.85rem; margin-bottom: 1rem;">
    <div style="padding: 1rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #00a66a; box-shadow: 0 4px 14px rgba(0, 40, 86, 0.05);">
      <div style="font-size: 0.78rem; color: #5c6b77; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.35rem; font-weight: 800;">Confirmed</div>
      <div style="font-weight: 800; color: #002856;">VLR appliance admin UI loads</div>
      <div style="margin-top: 0.25rem; color: #333333;"><code>https://&lt;vlr-fqdn&gt;:5480</code></div>
    </div>

    <div style="padding: 1rem; border-radius: 12px; background: #ffffff; border-left: 5px solid #d9534f; box-shadow: 0 4px 14px rgba(0, 40, 86, 0.05);">
      <div style="font-size: 0.78rem; color: #5c6b77; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.35rem; font-weight: 800;">Issue observed</div>
      <div style="font-weight: 800; color: #002856;">vCenter Site Recovery / VLR plugin</div>
      <div style="margin-top: 0.25rem; color: #333333;">Does not load correctly</div>
    </div>
  </div>

  <div style="padding: 1rem 1.1rem; border-radius: 14px; background: #ffffff; border: 1px solid #d7e8f7;">
    <div style="font-size: 0.78rem; color: #5c6b77; text-transform: uppercase; letter-spacing: 0.05em; margin-bottom: 0.75rem; font-weight: 800;">Check first</div>
    <ol style="margin: 0; padding-left: 1.2rem; color: #333333; line-height: 1.65;">
      <li><strong style="color: #002856;">DNS / FQDN:</strong> confirm vCenter and the VLR appliance resolve by FQDN, not just IP.</li>
      <li><strong style="color: #002856;">Certificate trust:</strong> confirm the VLR certificate CN/SAN matches the FQDN used by vCenter.</li>
      <li><strong style="color: #002856;">Extension keys:</strong> confirm vCenter extension registrations point to the correct VLR appliance.</li>
      <li><strong style="color: #002856;">VLR services:</strong> confirm the VLR backend services are running and healthy.</li>
      <li><strong style="color: #002856;">vSphere UI cache:</strong> restart <code>vsphere-ui</code> or use a clean browser session if plugin registration changed.</li>
    </ol>
  </div>
</div>

That can send you down the wrong path if you assume the appliance is completely fine because the admin UI works.

The places I would check first:

1. **Time/NTP** — especially if SAML or authentication errors appear.
2. **DNS/FQDN** — avoid short names and IP-based access paths.
3. **Certificate identity** — make sure the appliance certificate aligns with the FQDN.
4. **vCenter extension registration** — confirm extension entries point to the new VLR appliance, not an old SRM/VR appliance.
5. **vSphere UI refresh** — restart or refresh the vSphere Client service if the plugin appears stale.
6. **Replication NIC configuration** — for certain post-convergence VR plugin issues, validate the `hbrsrv-nic.xml` path called out in Broadcom guidance.

<div style="margin: 1.5rem 0; padding: 1rem 1.1rem; border-radius: 14px; background: #fffdf8; border: 1px solid #f0dfb7; border-left: 5px solid #c99700; color: #333333; line-height: 1.55;">
  <strong style="color: #002856;">Be careful with extension cleanup.</strong> Do not randomly remove vCenter extensions just because an extension key looks suspicious. Validate what the extension points to first. Removing the wrong active extension can make the situation worse.
</div>

## What I would do before the next window

If I had to run this again, I would prep the window with a short checklist:

- Inventory every SRM and vSphere Replication appliance.
- Validate build numbers, not just versions.
- Confirm the required 9.0.2.2 baseline before convergence.
- Stage the VLR 9.0.4 deployment media ahead of time.
- Confirm whether the deployable appliance files are inside the ISO.
- Take snapshots before each major phase.
- Confirm NTP/time on every appliance.
- Confirm DNS and certificate identity use FQDNs.
- Deploy one VLR appliance per participating site/vCenter.
- Validate the plugin from both sides before closing the change.

None of that is complicated, but missing any one of those checks can cost real time during a maintenance window.

## Final thoughts

The VMware Live Recovery 9.0.4 convergence path worked. The challenge was not the convergence itself as much as the surrounding details: naming, builds, media packaging, identity, certificates, and plugin behavior.

Once those pieces were clear, the process became much more manageable.

The main takeaway is simple:

> This is not just an upgrade. It is a convergence into a new appliance model.

And with that mindset, the rest of the process makes a lot more sense.

## References

- [Broadcom KB 408127: Steps to Converge to VMware Live Recovery Appliance 9.0.4](https://knowledge.broadcom.com/external/article?articleNumber=408127)
- [Broadcom KB 424908: After 9.0.4 or 9.0.5 converge VR plugin inaccessible and UI errors](https://knowledge.broadcom.com/external/article/424908/after-904-or-905-converge-vr-plugin-inac.html)
- [Broadcom KB 426469: VLSR plugin is not accessible from vCenter after convergence](https://knowledge.broadcom.com/external/article/426469/vlsr-plugin-is-not-accessible-from-vcent.html)
- [VMware Live Site Recovery 9.0.2.2 Release Notes](https://techdocs.broadcom.com/us/en/vmware-cis/live-recovery/live-site-recovery/9-0/release-notes/vmware-live-site-recovery-9022-release-notes.html)
- [Converge to the VMware Live Recovery Appliance](https://techdocs.broadcom.com/us/en/vmware-cis/live-recovery/live-recovery-appliance/9-0-4/upgrading-srm/migrate-to-the-combined-vmware-live-recovery-appliance.html)

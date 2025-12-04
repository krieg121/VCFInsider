---
layout: post
title: "NSX-T Segment Automation: Policy API Patterns That Don’t Break"
subtitle: "Exactly how I create routed segments with TZ selection and T1/T0 wiring — idempotent and safe to rerun"
date: 2025-12-03 09:00:00 -0500
author: Chris
categories: ["NSX-T"]
tags: ["nsx-t","policy-api","segments","automation","tier-1","tier-0"]
description: "My production-safe pattern for creating NSX-T segments via the Policy API: request shape, transport-zone path, T1/T0 connectivity, validation, rollback, and real troubleshooting."
image: /assets/images/posts/2025-11-13-nsxt-segment-automation-policy-api-patterns/nsxt-segment-automation-policy-api-patterns_1920x1080.webp
thumbnail: /assets/images/posts/2025-11-13-nsxt-segment-automation-policy-api-patterns/nsxt-segment-automation-policy-api-patterns_1920x1080.webp
og_image: /assets/images/posts/2025-11-13-nsxt-segment-automation-policy-api-patterns/nsxt-segment-automation-policy-api-patterns_1920x1080.webp
---

**Executive summary:** Here’s the Segment pattern I actually use in production. It’s **idempotent** (safe to rerun), pins the segment to the right **Transport Zone**, and wires it to **Tier-1** (or **Tier-0**) without side scripts. Copy it, change the IDs, and validate with the calls below.

## Prereqs & assumptions
- You’re on the **NSX Policy API** (the modern path).
- You know your overlay `transport_zone_path` and the `connectivity_path` for **Tier-1** (or **Tier-0**).
- You’ve picked the gateway subnet you want (e.g., `10.10.10.1/24`).

## My request shape (PUT, not PATCH)
**Why PUT?** I want idempotence. If I run it 10 times, I end up with the same object.

```bash
# Create/Update a routed overlay segment and connect it to T1
curl -k -u "$USER:$PASS" -X PUT   "https://<nsx-mgr>/policy/api/v1/infra/segments/<SEGMENT_ID>"   -H "Content-Type: application/json"   -d '{
    "display_name": "<SEGMENT_NAME>",
    "transport_zone_path": "/infra/sites/<SITE>/enforcement-points/<EP>/transport-zones/<TZ_ID>",
    "subnets": [
      { "gateway_address": "10.10.10.1/24" }
    ],
    "connectivity_path": "/infra/tier-1s/<T1_ID>"
  }'
```

### Optional add-ons I use

**Tags for ownership and environment**
```json
"tags": [
  {"scope": "owner", "tag": "automation"},
  {"scope": "env", "tag": "prod"}
]
```

**Admin state for controlled bring-up**
```json
"admin_state": "DOWN"
```

**Notes**
- Keep `<SEGMENT_ID>` **stable** so re-runs update in place.
- Always set `transport_zone_path` explicitly when multiple overlay TZs exist.
- Use `connectivity_path` for Tier-1 (or Tier-0). Omit it for a disconnected segment.

## Validation — my quick checklist

### 1) GET the segment
```bash
curl -k -u "$USER:$PASS"   "https://<nsx-mgr>/policy/api/v1/infra/segments/<SEGMENT_ID>"
```
Confirm `transport_zone_path`, `connectivity_path`, and `subnets[0].gateway_address`.

### 2) UI health
**Networking → Segments**. Status should be **Up** once T1/Edges are healthy.

### 3) Routing
On the **Tier-1**, verify the new prefix (e.g., `10.10.10.0/24`) is present and advertised per your design.

## Rollback (clean and predictable)
Detach ports/NICs first if necessary, then:

```bash
curl -k -u "$USER:$PASS" -X DELETE   "https://<nsx-mgr>/policy/api/v1/infra/segments/<SEGMENT_ID>"
```

Recheck Tier-1 routes; the prefix should withdraw.  
If DELETE complains about dependencies, you still have attached VIFs (VM NICs, DHCP bindings, etc.).

## Troubleshooting (field notes)
- **404 path:** One of `SITE/EP/TZ` is wrong, or you’re in a **Project** and pointing to the wrong scope. Pull a fresh `GET /infra` and copy exact paths.
- **409 conflict:** You’re changing schema on an existing ID. `GET` it, align, or **delete/recreate**.
- **Wrong TZ at scale:** Auto-assignment can bite when multiple overlay TZs exist. Set `transport_zone_path` every time.
- **No route showing up:** T1 isn’t linked to T0, route advertisement is restricted, or the Edge uplink is mis-wired. Start at the T1 relationship view and work outward.

## Patterns I don’t regret later
- **PUT with stable IDs** → safe reruns.  
- Keep segment **connectivity in the same intent** (this JSON), not in an after-the-fact call.  
- Store payloads in Git next to your IaC with tags, owners, and change notes.  
- In pipelines, add a dry-run step that does a **GET and diff** before the **PUT**; it catches fat-fingered paths.

# VCF Insider staging publication harness

This package adds a staging-only publication test around the existing VCF Insider deployment workflow. It does not replace or modify either of these known-good files:

- `scripts/Deploy-VCFInsider.ps1`
- `scripts/deploy-vcfinsider-remote.sh`

The harness has no production deployment parameter and contains no XenForo or social-media write operation. Its only optional repository write is an explicit, branch-protected community CTA front-matter update.

The new files live under underscore-prefixed directories so Jekyll does not copy the automation script, manifests, or social drafts into the generated website. No `_config.yml` change is required.

## Files

Copy these files into the matching locations in the VCF Insider repository:

```text
_automation/Test-VCFInsiderPublication.ps1
_automation/Publish-VCFInsiderXenForoThread.ps1
_automation/Prepare-VCFInsiderBufferPosts.ps1
_automation/STAGING-PUBLISHING-WORKFLOW.md
_publishing/publication-manifest.template.json
_publishing/2026-09-21-cyber-recovery-part2.example.json
```

## What it does

The harness:

1. Validates a JSON publication manifest.
2. Confirms the article source and exact front-matter title.
3. Writes proposed XenForo, LinkedIn, Facebook, and X content outside the repository.
4. Optionally uses the existing `Deploy-VCFInsider.ps1 -Staging` workflow.
5. Optionally verifies an already-deployed staging article.
6. Optionally authenticates to XenForo and performs the established exact-title duplicate search using GET requests only.
7. Validates the existing XenForo URL against `xenforo.thread_url` when the manifest supplies one.
8. Plans or applies the two community CTA front-matter fields with conflict detection and idempotency.
9. Writes a JSON release report.

It cannot:

- deploy production;
- create, update, or delete a XenForo thread;
- publish or schedule a social post;
- store API keys.

The CTA update cannot write directly to `main`. It stops without changing the article if an existing CTA value conflicts with the manifest. Applying a CTA and deploying staging must be separate runs so the change can be reviewed and committed first.

The XenForo publishing script keeps thread creation separate from deployment. It uses the proven API sequence: verify `/me/`, perform the paged exact-title duplicate search, POST to `/threads/`, and read the new thread back with `with_first_post=1`. Existing exact-title threads are successful no-ops; they are never reposted.

The Buffer planner keeps social-media writes inside the authenticated Codex session where the Buffer MCP connection exists. PowerShell validates the verified channel IDs, services, post text, publication mode, schedule offsets, and mandatory platform-specific link-preview metadata, then produces a deterministic plan and a guarded Codex request. The planner itself cannot create, schedule, modify, or delete Buffer content.

LinkedIn and Facebook article promotions are fail-closed: every enabled post must contain the complete verified `linkAttachment` payload with the production URL, exact article title, preview description, and hero thumbnail. X remains disabled because its current connected-channel and link-preview workflow has not been verified.

## Repository requirement for staging deployment

The existing staging deployment script requires:

- a focused non-`main` branch;
- a clean working tree;
- a matching branch pushed to GitLab.

Commit and push the new harness and manifest before testing `-DeployStaging`.

## Commands

Generate previews only:

```powershell
.\_automation\Test-VCFInsiderPublication.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json"
```

Generate previews and run read-only XenForo authentication and duplicate checks:

```powershell
.\_automation\Test-VCFInsiderPublication.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json" `
  -CheckXenForo
```

Plan the community CTA without modifying the article:

```powershell
.\_automation\Test-VCFInsiderPublication.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json" `
  -PlanCommunityCta
```

Apply the community CTA on a focused non-`main` branch:

```powershell
.\_automation\Test-VCFInsiderPublication.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json" `
  -ApplyCommunityCta
```

For the Part 2 example, both commands are expected to report `already-configured` because the verified Thread 32 fields are already present. A future article with both fields missing reports `would-update` during planning and adds them only when explicitly applied.

Verify the current staging article without deploying:

```powershell
.\_automation\Test-VCFInsiderPublication.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json" `
  -VerifyStaging
```

Run the existing interactive staging deployment, then verify the article:

```powershell
.\_automation\Test-VCFInsiderPublication.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json" `
  -DeployStaging `
  -CheckXenForo
```

The existing deployment script still requires typing its exact `STAGE <commit>` confirmation phrase.

## XenForo thread workflow

Check identity and duplicates without permitting a POST:

```powershell
.\_automation\Publish-VCFInsiderXenForoThread.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json"
```

For the Part 2 example, this must find and verify Thread 32 and finish with `write_performed: false`.

Permit creation for a future manifest only after its article has passed staging:

```powershell
.\_automation\Publish-VCFInsiderXenForoThread.ps1 `
  -ManifestPath ".\_publishing\YYYY-MM-DD-article-name.json" `
  -CreateThread
```

Before a live POST, the script requires all of the following:

- no exact-title duplicate;
- an empty `xenforo.thread_url` in the manifest;
- a focused non-`main` branch;
- a clean Git working tree;
- an HTTP 200 staging article containing the manifest's expected text;
- the exact interactive phrase `POST <release_name>`.

After a successful POST, the script uses the established read-back request and writes `xenforo-release-report.json` outside the repository. Copy the verified URL into `xenforo.thread_url`, then run the CTA plan/apply workflow. If a POST may have occurred but verification fails, inspect XenForo and do not rerun the command.

## Buffer publishing workflow

The manifest's `buffer` object contains the verified Buffer organization, LinkedIn channel, and Facebook channel IDs. It also contains the article-card metadata used for both platforms:

```json
"link_preview": {
  "title": "Exact article title from front matter",
  "description": "Concise description shown in the social link-preview card",
  "thumbnail_url": "https://www.vcfinsider.com/assets/images/posts/YYYY-MM-DD-article-slug/hero.webp"
}
```

The preview title must exactly match `article_title`. The thumbnail must be an HTTPS URL on `www.vcfinsider.com`. The generated LinkedIn input uses `metadata.linkedin.linkAttachment`; the Facebook input uses `metadata.facebook.linkAttachment` with `type: post`. Both use an empty `assets` array, matching the verified Buffer payloads.

For scheduled publication, keep `buffer.mode` set to `customScheduled`. Each enabled channel requires an approved future `due_at` value with an explicit Eastern offset:

```json
"enabled": true,
"due_at": "2026-09-22T10:30:00-04:00"
```

Use `-04:00` while Eastern Daylight Time is active and `-05:00` while Eastern Standard Time is active.

For immediate publication, set `buffer.mode` to `shareNow` and leave every enabled channel's `due_at` empty. The planner rejects ambiguous combinations, including `shareNow` with a `due_at` value.

The planner also rejects missing preview fields, preview-title drift, incorrect service mappings, repeated channel IDs, unsupported enabled channels, UTC timestamps, missing offsets, and past scheduled times. X cannot be enabled until its channel and preview behavior are separately verified.

Generate the Buffer plan without performing a write:

```powershell
.\_automation\Prepare-VCFInsiderBufferPosts.ps1 `
  -ManifestPath ".\_publishing\2026-09-21-cyber-recovery-part2.example.json"
```

This writes the following files outside the repository:

- `buffer-plan.json`
- `buffer-codex-request.txt`
- `buffer-release-report.json`

Open a Buffer-enabled ChatGPT or Codex session, paste the contents of `buffer-codex-request.txt`, and let it complete the first read-only turn. The request requires organization and channel verification, duplicate detection, complete payload review, and a non-null platform link attachment before approval. It requires the exact phrase `SCHEDULE <release_name>` for scheduled posts or `PUBLISH <release_name>` for immediate posts before any mutation.

Posts are created sequentially. After each write, the request requires a read-back verification of the post ID, channel, text, status, timing, and the complete platform `linkAttachment`. If a post is created but preview verification fails, stop and reconcile it manually; never automatically delete, recreate, or retry it.

To copy the generated request to the Windows clipboard:

```powershell
$request = "$env:USERPROFILE\Documents\VCFInsider-publishing-previews\<release_name>\buffer-codex-request.txt"
Get-Content -LiteralPath $request -Raw | Set-Clipboard
```

## Output

By default, previews are written to:

```text
%USERPROFILE%\Documents\VCFInsider-publishing-previews\<release_name>
```

The directory contains:

- `xenforo.txt`
- `linkedin.txt`
- `facebook.txt`
- `x.txt`
- `release-report.json`

The Buffer planner adds its own three files to this same release directory when it is run.

These outputs are deliberately outside the Git repository so they do not dirty the working tree or enter a deployment archive.

## Production boundary

Production orchestration should be implemented only after this staging harness completes a full test successfully. The production workflow should reuse the same manifest but remain a separate script with its own explicit approval and idempotency controls.

# VCF Insider Site Operations Runbook

This document is the working development, validation, and production deployment
runbook for VCF Insider.

Repository:

    https://github.com/krieg121/VCFInsider

Production site:

    https://www.vcfinsider.com/

Community:

    https://community.vcfinsider.com/

VCF Insider is a Jekyll site published with GitHub Pages.

---

## 1. Production rules

`main` is production.

Do not modify, merge into, force-update, or otherwise change `main` unless the
specific production change has been reviewed and explicitly approved by Chris.

Normal workflow:

1. Verify the current production `main`.
2. Create a focused test branch from that exact commit.
3. Make only the approved changes.
4. Build and preview locally.
5. Validate desktop and mobile behavior.
6. Review the complete branch-to-`main` diff.
7. Merge through a reviewed pull request only after explicit approval.
8. Verify the resulting `main` commit.
9. Smoke-test the live site.

Do not mix unrelated fixes into the same branch.

GitHub is the source of truth.

Local checkouts may contain untracked, experimental, backup, or temporary
files. Do not delete or overwrite those files simply to obtain a clean working
tree.

---

## 2. Verify production before starting

Always fetch the current remote state first:

```powershell
git fetch origin
git log -1 --oneline origin/main
```

Record or verify the production commit before creating a new branch.

Do not assume a previously remembered `main` SHA is still current.

---

## 3. Create a focused test branch

Create each site change from the current verified `origin/main`.

Example:

```powershell
git switch -c <test-branch> origin/main
```

Use a branch name that describes one task, for example:

```text
homepage-category-cards-test
blog-layout-fix-test
deployment-guide-refresh
```

If the normal checkout contains unrelated local files, do not disturb them just
to start a new task. Use a separate worktree instead.

---

## 4. Safe local worktrees

### Editing locally in an isolated worktree

For a new local task:

```powershell
git fetch origin
git worktree add -b <test-branch> ..\VCFInsider-<task> origin/main
cd ..\VCFInsider-<task>
```

This creates the task branch in a separate working directory without modifying
the primary checkout.

### Previewing an existing remote test branch

When the test branch already exists remotely:

```powershell
git fetch origin
git worktree add --detach ..\VCFInsider-preview origin/<test-branch>
cd ..\VCFInsider-preview
```

To refresh an existing preview worktree:

```powershell
git fetch origin
git switch --detach origin/<test-branch>
```

A detached preview worktree is for building and testing.

Do not make production commits from it.

---

## 5. Local dependencies

The project uses Bundler and the `github-pages` dependency set.

Install dependencies when setting up a new checkout or after dependency
changes:

```powershell
bundle install
```

Normal Jekyll commands should be run through Bundler:

```powershell
bundle exec jekyll build
bundle exec jekyll serve
```

This helps keep the local Jekyll environment aligned with the versions defined
by the repository.

---

## 6. Build before preview

Run:

```powershell
bundle exec jekyll build
```

The build must complete successfully before a change is considered ready.

Warnings are not automatically failures. Review the final build result and
distinguish non-blocking dependency/platform warnings from actual Jekyll
errors.

The generated `_site` directory is build output, not source content.

---

## 7. Local preview

Run:

```powershell
bundle exec jekyll serve
```

Open:

    http://127.0.0.1:4000/

Keep the Jekyll process running while testing.

After each final CSS, layout, or template adjustment, rebuild or refresh the
served branch and verify the actual rendered result rather than relying only on
the source diff.

---

## 8. Required visual validation

For CSS, layout, navigation, card, or template changes, validate at minimum:

- Desktop around 1440px wide
- Mobile around 390px wide
- Mobile around 430px wide

Check for:

- horizontal overflow
- clipped headings
- unexpected text wrapping
- broken navigation
- malformed category pills
- inconsistent card heights
- inconsistent button placement
- stretched or cropped images
- unreadable text
- bad contrast
- changes outside the intended section

When shared classes are modified, inspect other pages that use those classes.

Whenever possible, scope page-specific styling to a page-specific parent such
as:

```css
.home-page ...
body.blog-index ...
```

This reduces the risk of changing unrelated pages.

---

## 9. Validate the exact branch before merge

Fetch the latest remote refs:

```powershell
git fetch origin
```

Check whitespace:

```powershell
git diff --check origin/main...origin/<test-branch>
```

Review changed files and size:

```powershell
git diff --stat origin/main...origin/<test-branch>
```

Review the actual patch:

```powershell
git diff origin/main...origin/<test-branch>
```

Review the commits that would enter production:

```powershell
git log --oneline origin/main..origin/<test-branch>
```

Confirm:

- only expected files changed
- no temporary files were added
- no backup files were added
- no credentials or secrets are present
- no unrelated cleanup is included
- all requested fixes are present
- previously approved behavior remains intact

If `main` changed while the test branch was being developed, stop and review
the new relationship before merging.

Do not assume the old comparison is still valid.

---

## 10. Production merge workflow

Use a pull request from the reviewed test branch into `main`.

Before merging, verify:

- PR base is `main`
- PR head is the expected test branch
- PR head SHA matches the version that was reviewed
- changed-file list matches the approved scope
- the branch is mergeable
- desktop/mobile validation is complete

Merge only after Chris explicitly approves the production merge.

Afterward:

```powershell
git fetch origin
git log -1 --oneline origin/main
```

Record the new production commit SHA.

---

## 11. Post-deployment validation

After GitHub Pages publishes the new `main`, open:

    https://www.vcfinsider.com/

Check the pages directly affected by the change.

Also check at least one page that should not have changed.

For homepage changes, verify:

- hero
- Latest from the Field
- article cards
- category section
- navigation
- community links
- desktop layout
- mobile layout

For Blog index changes, verify:

- `/blog/`
- card layout
- category labels
- article links
- mobile stacking

For article-template changes, open at least one real article.

A successful Git merge does not by itself prove that the live site renders
correctly.

---

## 12. Publishing new articles

Posts live in:

```text
_posts/
```

The current post format commonly includes front matter such as:

```yaml
layout: post
title:
description:
excerpt:
date:
author:
categories:
tags:
image:
thumbnail:
og_image:
hero_image_path:
```

Not every field is required for every template, but new articles should follow
the established metadata pattern used by recent production posts.

In particular, keep:

- a valid publication date
- an authored category label
- a useful excerpt
- a card/hero image
- social image metadata where applicable

Do not invent new category spelling or capitalization casually. Category labels
and category URLs are handled separately by the site.

---

## 13. Homepage article behavior

`Latest from the Field` is generated automatically from the four newest posts.

The homepage template loops over:

```liquid
{% raw %}
{% for post in site.posts limit:4 %}
{% endraw %}
```

A new article therefore appears automatically when it becomes one of the four
newest posts.

Homepage cards automatically inherit the shared homepage presentation,
including:

- article image
- category pill
- title
- excerpt
- publication date
- Read More button
- NEW badge for recently published posts

The homepage currently looks for:

```liquid
post.featured_image
```

and falls back to:

```liquid
post.image
```

Current production posts commonly use `image`.

No hand-built homepage card is required for each article.

---

## 14. Category handling

Preserve authored category labels such as:

```text
Cloud Foundation
AI & Automation
NSX-T
VCF 9.1
VMware Cloud Foundation
```

Do not change category URLs merely to alter the visible label.

If a category label renders incorrectly, trace the Liquid/template rendering
path before attempting to fix it with CSS.

After category-related changes, validate:

- homepage cards
- Blog index
- category pages
- category URLs

---

## 15. Custom-domain configuration

The production domain is:

    https://www.vcfinsider.com

The repository currently contains:

```yaml
url: "https://www.vcfinsider.com"
baseurl: ""
```

and the `CNAME` file contains:

```text
www.vcfinsider.com
```

Do not change `_config.yml`, `CNAME`, DNS, or GitHub Pages domain settings as
part of unrelated development work.

A domain change should be handled as its own reviewed task.

---

## 16. Scope discipline

Keep each branch focused.

A homepage change should not silently modify:

- Blog index layout
- article templates
- navigation
- analytics
- community behavior

A Blog index change should not silently modify:

- homepage cards
- article pages
- navigation
- analytics

A documentation change should not include application code changes.

If testing reveals a second unrelated issue, record it and handle it in a
separate task unless it is directly caused by the current patch.

---

## 17. Rollback

If a production change causes a significant problem:

1. Identify the production commit that introduced the issue.
2. Identify the previous known-good production commit.
3. Determine whether a targeted repair or revert is safer.
4. Preview the repair when practical.
5. Review the exact patch.
6. Obtain explicit approval.
7. Apply the repair.
8. Verify the live site again.

Do not force-reset `main` or rewrite production history as a routine rollback
method.

---

## 18. Secrets and sensitive files

Never commit:

- API keys
- passwords
- access tokens
- database credentials
- private backups
- private configuration exports

Do not place secrets in:

- Markdown documentation
- screenshots
- commit messages
- issue descriptions
- terminal transcripts

The VCF Insider Community API has its own runbook:

```text
XENFORO_API_RUNBOOK.md
```

Forum writes and VCF Insider repository writes are separate operations and
require separate approval.

---

## 19. Important source locations

```text
_config.yml        Jekyll/site configuration
CNAME              Production custom domain
_layouts/          Page and post layouts
_includes/         Shared Liquid components
_pages/            Static pages
_posts/            Published articles
assets/css/        Site CSS
assets/js/         Site JavaScript
assets/images/     Site and article images
index.html         Homepage
```

Current site dependencies include:

- Jekyll via GitHub Pages
- Minima
- jekyll-feed
- jekyll-sitemap
- jekyll-seo-tag
- custom VCF Insider CSS and JavaScript

---

## 20. Definition of done

Before a site change is considered complete:

- [ ] Current `origin/main` verified
- [ ] Test branch based on intended production commit
- [ ] Exact scope identified
- [ ] Proposed patch reviewed before implementation
- [ ] Only approved files changed
- [ ] `git diff --check` passes
- [ ] Jekyll build succeeds
- [ ] Desktop preview validated
- [ ] 390px mobile preview validated
- [ ] 430px mobile preview validated
- [ ] No horizontal overflow
- [ ] No unintended shared-style regressions
- [ ] Final branch-to-`main` diff reviewed
- [ ] Production merge explicitly approved
- [ ] PR head SHA re-verified before merge
- [ ] New `main` SHA recorded
- [ ] Live site smoke-tested

---

Last materially updated: September 2026.

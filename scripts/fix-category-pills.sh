#!/usr/bin/env bash
# Make blue, rounded .article-category pills the site-wide default (clean, safe).
# Usage:
#   ./scripts/fix-category-pills.sh        # apply
#   ./scripts/fix-category-pills.sh -n     # dry run (no writes)

set -euo pipefail
shopt -s nullglob

DRYRUN=0
[[ "${1:-}" == "-n" || "${1:-}" == "--dry-run" ]] && DRYRUN=1

repo_root="$(pwd)"
echo "==> Repo: $repo_root"

if [[ ! -f "_config.yml" ]]; then
  echo "ERROR: Not a Jekyll repo root (missing _config.yml)."
  exit 1
fi

# 0) Preflight: confirm vcf-insider.css is referenced (no change, just info)
if grep -q 'vcf-insider\.css' _layouts/default.html 2>/dev/null; then
  echo "✓ vcf-insider.css is referenced in _layouts/default.html"
else
  echo "! NOTE: Could not find vcf-insider.css link in _layouts/default.html (site may not load your styles)."
fi

# 1) Create the reusable include
mkdir -p _includes
include_path="_includes/category_pill.html"
include_body='{% comment %}
Reusable category pill component — uses .article-category (blue rounded).
Usage:
  {% include category_pill.html categories=page.categories %}
  {% include category_pill.html categories=post.categories %}
{% endcomment %}

{% assign cats = include.categories | default: page.categories | default: post.categories %}
{% if cats and cats.size > 0 %}
  {% for cat in cats %}
    <a class="article-category" href="{{ "/categories/" | append: cat | slugify | append: "/" | relative_url }}">
      {{ cat }}
    </a>
  {% endfor %}
{% endif %}'

if [[ $DRYRUN -eq 1 ]]; then
  if [[ -f "$include_path" ]]; then
    echo "DRYRUN: would ensure $include_path exists (already present)"
  else
    echo "DRYRUN: would create $include_path"
  fi
else
  printf '%s\n' "$include_body" > "$include_path"
  echo "✓ Ensured $include_path"
fi

# Helper: safe in-place edit with backup (first time only)
backup_once() { local f="$1"; [[ -f "${f}.bak" ]] || cp -f "$f" "${f}.bak"; }

# 2) Single post layout — replace only if the line actually prints page.categories
if [[ -f "_layouts/post.html" ]]; then
  file="_layouts/post.html"
  if grep -Eq '<(span|a)[^>]*class="[^"]*\b(post-category|badge|badge-primary|label)\b[^"]*"[^>]*>[^{}]*\{\{\s*page\.categories[^}]*\}\}' "$file"; then
    echo "-> Updating $file"
    if [[ $DRYRUN -eq 1 ]]; then
      echo "DRYRUN: would replace legacy category badge line(s) with include"
    else
      backup_once "$file"
      # Replace any badge/post-category element that prints page.categories on the same line
      sed -i -E \
        's@<(span|a)[^>]*class="[^"]*\b(post-category|badge|badge-primary|label)\b[^"]*"[^>]*>[^{}]*\{\{\s*page\.categories[^}]*\}\}[^<]*</(span|a)>@{% include category_pill.html categories=page.categories %}@g' \
        "$file"
      echo "✓ _layouts/post.html updated"
    fi
  else
    # If it uses an if-block, rewrite only the block contents, preserve if/endif
    if grep -Eq '\{%-?\s*if\s+page\.categories' "$file"; then
      echo "-> Rewriting page.categories if-block in $file (content only)"
      if [[ $DRYRUN -eq 1 ]]; then
        echo "DRYRUN: would replace if-block body with include"
      else
        backup_once "$file"
        awk '
          BEGIN{ inblk=0 }
          /{%-?[[:space:]]*if[[:space:]]+page\.categories/ { print; inblk=1; next }
          inblk && /{%-?[[:space:]]*endif[[:space:]]*-?%}/ { print "  {% include category_pill.html categories=page.categories %}"; print; inblk=0; next }
          inblk { next }
          { print }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        echo "✓ _layouts/post.html if-block rewritten"
      fi
    else
      echo "i _layouts/post.html: no legacy category badge detected"
    fi
  fi
else
  echo "i _layouts/post.html not found; skipping"
fi

# 3) Listing/card templates — change only lines that actually print post.categories
candidates=(
  "_includes/post-card.html"
  "_layouts/blog.html"
  "_layouts/home.html"
  "_layouts/index.html"
  "_pages/blog.html"
  "_pages/blog.md"
  "index.html"
  "blog.html"
  "blog.md"
)

changed_list=()

update_listing_file() {
  local f="$1"
  local did=0
  # Only replace if a badge/post-category element prints post.categories on the SAME line
  if grep -Eq '<(span|a)[^>]*class="[^"]*\b(post-category|badge|badge-primary|label)\b[^"]*"[^>]*>[^{}]*\{\{\s*post\.categories[^}]*\}\}' "$f"; then
    echo "-> Updating $f"
    if [[ $DRYRUN -eq 1 ]]; then
      echo "DRYRUN: would replace legacy badge lines in $f"
      return 0
    fi
    backup_once "$f"
    sed -i -E \
      's@<(span|a)[^>]*class="[^"]*\b(post-category|badge|badge-primary|label)\b[^"]*"[^>]*>[^{}]*\{\{\s*post\.categories[^}]*\}\}[^<]*</(span|a)>@{% include category_pill.html categories=post.categories %}@g' \
      "$f"
    did=1
  fi
  # Also catch the common "first category" variant on the same line
  if grep -Eq '<(span|a)[^>]*>[^{}]*\{\{\s*post\.categories\s*\|\s*first\s*\}\}' "$f"; then
    if [[ $DRYRUN -eq 1 ]]; then
      echo "DRYRUN: would replace first-category badge lines in $f"
      return 0
    fi
    backup_once "$f"
    sed -i -E \
      's@<(span|a)[^>]*>[^{}]*\{\{\s*post\.categories\s*\|\s*first\s*\}\}[^<]*</(span|a)>@{% include category_pill.html categories=post.categories %}@g' \
      "$f"
    did=1
  fi
  [[ $did -eq 1 ]] && changed_list+=("$f")
}

for f in "${candidates[@]}"; do
  [[ -f "$f" ]] || continue
  # Only consider files that actually loop posts
  if grep -Eq '\{%[^%]*for[[:space:]]+post[[:space:]]+in' "$f"; then
    update_listing_file "$f"
  fi
done

# Deep scan includes/layouts for other post loops (safe: still requires post.categories on same line)
mapfile -t loop_files < <(grep -RIl --include='*.html' --include='*.md' -E '\{%[^%]*for[[:space:]]+post[[:space:]]+in' _includes _layouts 2>/dev/null || true)
for f in "${loop_files[@]}"; do
  update_listing_file "$f"
done

echo
echo "==> Summary"
[[ $DRYRUN -eq 1 ]] && echo "Mode: DRY RUN (no changes were written)"
echo "Include: $include_path (ensured)"
if [[ ${#changed_list[@]} -gt 0 ]]; then
  printf 'Updated listing files:\n'
  printf '  - %s\n' "${changed_list[@]}"
else
  echo "No listing files needed changes (or patterns not found)."
fi
echo "Backups: any modified file also has a .bak alongside it."
echo
echo "Next:"
echo "  git diff                                         # review changes"
echo "  bundle exec jekyll serve --livereload            # preview"
echo "  Hard-refresh /blog and a post page               # confirm blue rounded pills everywhere"

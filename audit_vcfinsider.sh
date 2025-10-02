#!/usr/bin/env bash
# Audits your VCFInsider Jekyll repo for consistent config, layouts, CSS, and category logic.
# Usage:  chmod +x audit_vcfinsider.sh && ./audit_vcfinsider.sh
set -euo pipefail

# Colors
PASS="\033[1;32mPASS\033[0m"
WARN="\033[1;33mWARN\033[0m"
FAIL="\033[1;31mFAIL\033[0m"
INFO="\033[36mINFO\033[0m"

OUT_DIR="_audit"
REPORT_TXT="$OUT_DIR/report.txt"
mkdir -p "$OUT_DIR"
: > "$REPORT_TXT"

fail_any=0

say(){ printf "%b\n" "$1" | tee -a "$REPORT_TXT"; }
header(){ say "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; say "🔎  $1"; say "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"; }
exists(){ [[ -f "$1" ]]; }
grepq(){ grep -Eqs "$1" "$2"; }

# 0) prerequisites
for cmd in grep awk sed head tr; do
  command -v "$cmd" >/dev/null 2>&1 || { say "$WARN  '$cmd' not found in PATH (script may not work fully)"; }
done

# 1) _config.yml
header "_config.yml"
if ! exists "_config.yml"; then
  say "$FAIL  _config.yml missing"; fail_any=1
else
  grepq '^url:\s*"?https?://(www\.)?vcfinsider\.com"?\s*$' _config.yml \
    && say "$PASS  url points to https://www.vcfinsider.com" \
    || say "$WARN  url not set to https://www.vcfinsider.com"
  grepq '^baseurl:\s*""\s*$' _config.yml \
    && say "$PASS  baseurl is empty (\"\")" \
    || { say "$FAIL  baseurl is not empty — set baseurl: \"\" for custom domain"; fail_any=1; }
fi

# 2) default layout includes
header "_layouts/default.html"
if ! exists "_layouts/default.html"; then
  say "$FAIL  _layouts/default.html missing"; fail_any=1
else
  grepq 'vcf-insider\.css' _layouts/default.html \
    && say "$PASS  vcf-insider.css is linked in <head>" \
    || { say "$FAIL  vcf-insider.css not linked in <head>"; fail_any=1; }
  grep -Eqs '(cdnjs\.cloudflare\.com/.*/font-?awesome|kit\.fontawesome\.com|/fontawesome/)' _layouts/default.html \
    && say "$PASS  Font Awesome is linked" \
    || say "$WARN  Font Awesome not found in <head> (icons may not render)"
fi

# 3) CSS tokens + pill style
header "assets/css/vcf-insider.css"
if ! exists "assets/css/vcf-insider.css"; then
  say "$FAIL  assets/css/vcf-insider.css missing"; fail_any=1
else
  # patterns beginning with '-' must use -F and '--'
  grep -Fqs -- '--vmware-' assets/css/vcf-insider.css \
    && say "$PASS  VMware theme tokens present (--vmware-*)" \
    || say "$WARN  No --vmware-* CSS vars found (optional)"
  grep -Eqs '\.article-category' assets/css/vcf-insider.css \
    && say "$PASS  .article-category pill style is defined" \
    || { say "$FAIL  .article-category pill style missing"; fail_any=1; }
fi

# 4) category layout inheritance
header "_layouts/category.html"
if ! exists "_layouts/category.html"; then
  say "$FAIL  _layouts/category.html missing"; fail_any=1
else
  if head -n 20 _layouts/category.html | grep -Eq '^---(\r)?$'; then
    if head -n 20 _layouts/category.html | grep -Eq '^layout:\s*(page|default)\s*(\r)?$'; then
      lay=$(head -n 20 _layouts/category.html | sed -n 's/^layout:\s*\(.*\)\s*$/\1/p' | head -1 | tr -d '\r')
      say "$PASS  category layout inherits: $lay"
      [[ "$lay" == "page" && ! -f _layouts/page.html ]] && say "$WARN  layout: page used, but _layouts/page.html not found (ok if theme provides it)"
    else
      say "$FAIL  category layout front matter missing 'layout: page|default'"; fail_any=1
    fi
  else
    say "$WARN  category layout lacks front matter block (---)"
  fi
fi

# 5) categories index logic (colors/icons)
header "_pages/categories.md"
if ! exists "_pages/categories.md"; then
  say "$FAIL  _pages/categories.md missing"; fail_any=1
else
  grepq 'assign +icon += +p\.icon' _pages/categories.md \
    && say "$PASS  categories.md uses icon from page front matter" \
    || { say "$FAIL  categories.md is not reading p.icon"; fail_any=1; }
  grepq 'assign +accent_color += +p\.accent' _pages/categories.md \
    && say "$PASS  categories.md uses accent from page front matter" \
    || { say "$FAIL  categories.md is not reading p.accent"; fail_any=1; }
  if grep -Fqs -- '--accent-color' _pages/categories.md; then
    say "$PASS  cards set CSS var --accent-color inline"
  else
    say "$WARN  cards do not set --accent-color (colors may default)"
  fi
  grep -Eqs 'class="card-link"|class="category-card"' _pages/categories.md \
    && say "$PASS  card markup detected (card-link/category-card)" \
    || say "$WARN  card markup not detected"
fi

# 6) category pages front matter (robust to BOM/CRLF/Unicode)
header "_pages/categories-*.md (front matter)"
shopt -s nullglob
for f in _pages/categories-*.md; do
  # Extract YAML FM: strip BOM, normalize CRLF
  fm=$(
    awk '
      NR==1 { sub(/^\xEF\xBB\xBF/,"") }
      !INS && $0 ~ /^---\r?$/ { INS=1; next }
      INS  && $0 ~ /^---\r?$/ { exit }
      INS { print }
    ' "$f" 2>/dev/null | tr -d '\r'
  )

  # Presence checks (more tolerant for Unicode values)
  has_layout=$(printf "%s\n" "$fm" | grep -Eq '^[[:space:]]*layout:[[:space:]]*category[[:space:]]*$' && echo yes || echo no)
  has_title=$(printf "%s\n" "$fm" | grep -Eq '^[[:space:]]*title:[[:space:]]*.+$' && echo yes || echo no)
  has_permalink=$(printf "%s\n" "$fm" | grep -Eq '^[[:space:]]*permalink:[[:space:]]*/categories/.+/$' && echo yes || echo no)
  has_category=$(printf "%s\n" "$fm" | grep -Eq '^[[:space:]]*category:[[:space:]]*.+$' && echo yes || echo no)
  has_icon=$(printf "%s\n" "$fm" | grep -Eq '^[[:space:]]*icon:[[:space:]]*.+$' && echo yes || echo no)

  # Accent extraction (strip quotes/spaces, allowing for comments)
  accent_raw=$(printf "%s\n" "$fm" | sed -n 's/^[[:space:]]*accent:[[:space:]]*\(.*\)$/\1/p' | head -1)
  # remove surrounding quotes and trailing comments/space
  accent_norm=$(printf "%s" "$accent_raw" | sed -E 's/"//g; s/'"'"'//g; s/[[:space:]]+#.*$//; s/[[:space:]]+$//' )

  # Compute slug(category) vs permalink slug for a consistency hint
  category_val=$(printf "%s\n" "$fm" | sed -n 's/^[[:space:]]*category:[[:space:]]*\(.*\)$/\1/p' | head -1 | sed -E 's/^"|"$//g' )
  permalink_val=$(printf "%s\n" "$fm" | sed -n 's/^[[:space:]]*permalink:[[:space:]]*\(.*\)$/\1/p' | head -1 | sed -E 's/^"|"$//g' )
  slug_cat=$(printf "%s" "$category_val" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
  slug_link=$(printf "%s" "$permalink_val" | sed -E 's#^/categories/##; s#/$##;' )

  ok=1
  [[ "$has_layout" == "yes" ]] || { say "$FAIL  $f : layout is not 'category'"; ok=0; }
  [[ "$has_title" == "yes" ]] || { say "$FAIL  $f : title missing"; ok=0; }
  [[ "$has_permalink" == "yes" ]] || { say "$FAIL  $f : permalink should be /categories/<slug>/"; ok=0; }
  [[ "$has_category" == "yes" ]] || { say "$FAIL  $f : category missing"; ok=0; }

  [[ "$has_icon" == "yes" ]] && say "$PASS  $f : icon present" || say "$WARN  $f : icon missing"

  if [[ "$accent_norm" =~ ^#[0-9A-Fa-f]{3,8}$ ]]; then
    say "$PASS  $f : accent is hex ($accent_norm)"
  else
    say "$WARN  $f : accent not a hex color (e.g. #0077C8)"
  fi

  [[ -n "$slug_cat" && "$slug_cat" == "$slug_link" ]] || say "$WARN  $f : permalink slug != slug(category)"
  [[ $ok -eq 1 ]] || fail_any=1
done
shopt -u nullglob

# 7) index.html checks
header "index.html"
if ! exists "index.html"; then
  say "$FAIL  index.html missing"; fail_any=1
else
  grep -Eqs 'post\.categories\s*\|\s*first' index.html \
    && say "$PASS  Latest Articles uses post.categories | first" \
    || { say "$FAIL  Latest Articles not using post.categories | first"; fail_any=1; }
  grep -Eqs '_category_pages.*where_exp' index.html && grep -Eqs 'cat_url' index.html \
    && say "$PASS  Homepage resolves per-category URLs with cat_url" \
    || { say "$FAIL  Homepage lacks cat_url resolution for category cards"; fail_any=1; }
  if grep -Eqs 'href="/categories/' index.html; then
    say "$WARN  Found hard-coded /categories/ links in index.html (prefer cat_url | relative_url)"
  else
    say "$PASS  No hard-coded /categories/ links in index.html"
  fi
  grep -qs '{#' index.html \
    && say "$WARN  Found Jinja-style {# ... #} comments (Liquid will print them)" \
    || say "$PASS  No Jinja-style {# ... #} comments"
fi

say "\n$INFO  Wrote text report to $REPORT_TXT"

# Exit nonzero if any FAIL occurred
[[ $fail_any -eq 0 ]] || exit 2
exit 0

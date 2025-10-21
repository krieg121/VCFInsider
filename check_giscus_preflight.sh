#!/usr/bin/env bash
# check_giscus_preflight.sh (portable, no-awk version)
set -u

RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; CYAN=$'\e[36m'; RESET=$'\e[0m'
failures=0
ok()   { printf "${GREEN}✅ %s${RESET}\n" "$*"; }
bad()  { printf "${RED}❌ %s${RESET}\n" "$*"; failures=$((failures+1)); }
warn() { printf "${YELLOW}⚠️  %s${RESET}\n" "$*"; }
note() { printf "${CYAN}%s${RESET}\n" "$*"; }

INC_FILE="_includes/comments.html"
LAYOUT="_layouts/default.html"
CFG="_config.yml"

# --- 1) _includes/comments.html existence + content ---
if [[ -f "$INC_FILE" ]]; then
  ok "Found $INC_FILE"
  grep -q 'giscus.app/client.js' "$INC_FILE" && ok "comments.html loads giscus.app script" || bad "comments.html missing giscus script"
  for v in \
    'data-repo="{{ site.giscus.repo }}"' \
    'data-repo-id="{{ site.giscus.repo_id }}"' \
    'data-category="{{ site.giscus.category }}"' \
    'data-category-id="{{ site.giscus.category_id }}"'
  do
    grep -Fq "$v" "$INC_FILE" && ok "comments.html uses Liquid var: $v" || bad "comments.html missing or hardcoding: $v"
  done
else
  bad "Missing _includes/comments.html (create it)."
fi

# --- 2) _layouts/default.html include & guards & order ---
if [[ -f "$LAYOUT" ]]; then
  ok "Found $LAYOUT"
  grep -q '{% include comments.html %}' "$LAYOUT" && ok "default.html includes comments.html" || bad "default.html does not include comments.html"

  # Guard for posts
  (grep -q "page.layout" "$LAYOUT" && grep -q "post" "$LAYOUT") || \
  (grep -q "page.collection" "$LAYOUT" && grep -q "posts" "$LAYOUT") \
    && ok "Post-only guard present (layout/posts condition)" \
    || bad "Post-only guard not detected; add the {% if page.layout == 'post' or page.collection == 'posts' %} guard."

  # Ensure include appears AFTER {{ content }}
  content_line=$(grep -n '{{[[:space:]]*content[[:space:]]*}}' "$LAYOUT" | head -n1 | cut -d: -f1)
  include_line=$(grep -n '{% include comments.html %}' "$LAYOUT" | head -n1 | cut -d: -f1)
  if [[ -n "${content_line}" && -n "${include_line}" ]]; then
    if (( include_line > content_line )); then
      ok "Include appears after {{ content }} (good placement)"
    else
      bad "Include appears before {{ content }}; move it below the content."
    fi
  else
    [[ -z "${content_line}" ]] && bad "Could not find '{{ content }}' in default.html"
    [[ -z "${include_line}"   ]] && warn "Could not find the include line number (already flagged if missing)."
  fi
else
  bad "Missing _layouts/default.html"
fi

# --- 3) _config.yml giscus block + required keys w/ non-placeholder values ---
if [[ -f "$CFG" ]]; then
  ok "Found $CFG"

  # Find the 'giscus:' block start (line number)
  start=$(grep -n '^[[:space:]]*giscus:[[:space:]]*$' "$CFG" | head -n1 | cut -d: -f1)
  if [[ -z "$start" ]]; then
    bad "No 'giscus:' block found in _config.yml"
  else
    ok "'giscus:' block present"

    # Extract the block lines after 'giscus:' until the next empty line or EOF (CRLF-safe)
    block=$(tail -n +"$((start+1))" "$CFG" | tr -d '\r' | sed -n '1,/^[[:space:]]*$/p')

    get_val () {
      key="$1"
      printf "%s\n" "$block" | sed -n -E "s/^[[:space:]]*${key}:[[:space:]]*\"?([^\"]*)\"?[[:space:]]*$/\1/p" | head -n1
    }

    repo=$(get_val "repo")
    repo_id=$(get_val "repo_id")
    category=$(get_val "category")
    category_id=$(get_val "category_id")

    [[ -n "$repo"       ]] && ok "giscus.repo = $repo"         || bad "Missing giscus.repo"
    [[ -n "$repo_id"    ]] && ok "giscus.repo_id = $repo_id"   || bad "Missing giscus.repo_id"
    [[ -n "$category"   ]] && ok "giscus.category = $category" || bad "Missing giscus.category"
    [[ -n "$category_id" ]] && ok "giscus.category_id = $category_id" || bad "Missing giscus.category_id"

    case "$category" in *ENTER*|*REPLACE* ) bad "giscus.category looks like a placeholder: '$category'";; esac
    case "$category_id" in *ENTER*|*REPLACE* ) bad "giscus.category_id looks like a placeholder: '$category_id'";; esac
    case "$repo_id" in R_* ) : ;; "" ) : ;; * ) warn "giscus.repo_id format looks unusual (expected to start with 'R_'); verify from giscus.app";; esac
  fi
else
  bad "Missing _config.yml"
fi

echo
if (( failures == 0 )); then
  ok "Giscus preflight passed. You’re ready to preview locally."
  echo "Run: bundle exec jekyll clean && JEKYLL_ENV=development bundle exec jekyll serve --livereload"
  exit 0
else
  bad "Giscus preflight found $failures issue(s). Fix and re-run."
  exit 1
fi

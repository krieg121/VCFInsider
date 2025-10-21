#!/usr/bin/env bash
# giscus_diagnose.sh (robust: no jq, trims quotes, infers Discussions from categories)
set -u

RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; CYAN=$'\e[36m'; RESET=$'\e[0m'
failures=0
ok(){ printf "${GREEN}✅ %s${RESET}\n" "$*"; }
bad(){ printf "${RED}❌ %s${RESET}\n" "$*"; failures=$((failures+1)); }
warn(){ printf "${YELLOW}⚠️  %s${RESET}\n" "$*"; }
note(){ printf "${CYAN}%s${RESET}\n" "$*"; }
need_cmd(){ command -v "$1" >/dev/null 2>&1 || { bad "Missing required command: $1"; return 1; }; }

INC_FILE="_includes/comments.html"
LAYOUT="_layouts/default.html"
CFG="_config.yml"

echo "== Giscus Diagnostics =="

# Tools
need_cmd gh || { echo "Install GitHub CLI: https://cli.github.com"; exit 1; }
ok "Dependency present: gh"

# Local wiring
echo
echo "-- Local file wiring --"
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
  bad "Missing $INC_FILE (create it with your Giscus snippet)."
fi

if [[ -f "$LAYOUT" ]]; then
  ok "Found $LAYOUT"
  grep -q '{% include comments.html %}' "$LAYOUT" && ok "default.html includes comments.html" || bad "default.html does not include comments.html"
  (grep -q "page.layout" "$LAYOUT" && grep -q "post" "$LAYOUT") || \
  (grep -q "page.collection" "$LAYOUT" && grep -q "posts" "$LAYOUT") \
    && ok "Post-only guard present (layout/posts condition)" \
    || bad "Post-only guard not detected; add the post guard around the include."
  content_line=$(grep -n '{{[[:space:]]*content[[:space:]]*}}' "$LAYOUT" | head -n1 | cut -d: -f1)
  include_line=$(grep -n '{% include comments.html %}' "$LAYOUT" | head -n1 | cut -d: -f1)
  if [[ -n "${content_line}" && -n "${include_line}" ]]; then
    (( include_line > content_line )) && ok "Include appears after {{ content }}" || bad "Include appears before {{ content }}; move it below content."
  else
    [[ -z "${content_line}" ]] && bad "Could not find '{{ content }}' in default.html"
  fi
else
  bad "Missing $LAYOUT"
fi

[[ -f "$CFG" ]] && ok "Found $CFG" || bad "Missing $CFG"

# Parse _config.yml giscus block
repo=""; repo_id=""; category=""; category_id=""
if [[ -f "$CFG" ]]; then
  start=$(grep -n '^[[:space:]]*giscus:[[:space:]]*$' "$CFG" | head -n1 | cut -d: -f1)
  if [[ -z "$start" ]]; then
    bad "No 'giscus:' block found in _config.yml"
  else
    ok "'giscus:' block present"
    block=$(tail -n +"$((start+1))" "$CFG" | tr -d '\r')
    block=$(printf "%s\n" "$block" | sed -n '1,/^[^[:space:]].*:[[:space:]]*$/p')
    get_val () {
      key="$1"
      line=$(printf "%s\n" "$block" | grep -E "^[[:space:]]*${key}:[[:space:]]*" | head -n1)
      # strip key:, inline comments, surrounding quotes, and trim
      val=$(printf "%s" "$line" | sed -E 's/^[[:space:]]*[^:]+:[[:space:]]*//; s/[[:space:]]*(#.*)$//; s/^[[:space:]]+|[[:space:]]+$//g; s/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')
      printf "%s" "$val"
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
    [[ -n "$repo_id" && "$repo_id" != R_* ]] && warn "giscus.repo_id format unusual (expected to start with 'R_'); verify from giscus.app"
  fi
fi

# Abort if local config incomplete
if [[ -z "${repo:-}" || -z "${repo_id:-}" || -z "${category:-}" || -z "${category_id:-}" ]]; then
  echo; bad "Local configuration incomplete; fix _config.yml and re-run."; exit 1
fi

# GitHub-side checks
echo
echo "-- GitHub-side checks --"
origin_url=$(git config --get remote.origin.url 2>/dev/null || true)
owner_repo=""
if [[ "$origin_url" =~ github.com[:/](.+/[^/.]+)(\.git)?$ ]]; then owner_repo="${BASH_REMATCH[1]}"; fi
[[ -z "$owner_repo" ]] && owner_repo="$repo"
owner="${owner_repo%/*}"; reponame="${owner_repo#*/}"
note "Repository detected: $owner/$reponame"

# Repo id via GraphQL (compare)
actual_repo_id=$(gh api graphql -f query='query($o:String!,$r:String!){repository(owner:$o,name:$r){id}}' -F o="$owner" -F r="$reponame" --jq '.data.repository.id' 2>/dev/null || echo "")
[[ -n "$actual_repo_id" && "$actual_repo_id" == "$repo_id" ]] && ok "repo_id matches GitHub GraphQL repository.id" || bad "repo_id mismatch: _config.yml='$repo_id' vs GitHub='$actual_repo_id'"

# Categories list (also implies Discussions enabled if it returns)
cats=$(gh api graphql -f query='
  query($o:String!,$r:String!){
    repository(owner:$o, name:$r){
      discussionCategories(first:100){ nodes{ id name } }
    }
  }' -F o="$owner" -F r="$reponame" --jq '.data.repository.discussionCategories.nodes[] | "\(.name)|\(.id)"' 2>/dev/null || echo "")
if [[ -n "$cats" ]]; then
  ok "Discussions API reachable; categories listed (Discussions enabled)."
  found_line=$(printf "%s\n" "$cats" | grep -E "^${category}\|" || true)
  if [[ -z "$found_line" ]]; then
    bad "Discussions category named '${category}' not found in $owner/$reponame"
    echo "Available categories:"; printf "%s\n" "$cats" | sed 's/^/  - /'
  else
    actual_cat_id="${found_line#*|}"
    ok "Found Discussions category: $category"
    [[ "$actual_cat_id" == "$category_id" ]] && ok "category_id matches GitHub Discussions category.id" || bad "category_id mismatch: _config.yml='$category_id' vs GitHub='$actual_cat_id'"
  fi
else
  bad "Could not list Discussions categories. Ensure Discussions is enabled and gh has access."
fi

# Giscus App installation (best effort)
app_slug=$(gh api "/repos/$owner/$reponame/installation" --jq '.app.slug' 2>/dev/null || echo "")
[[ "$app_slug" == "giscus" ]] && ok "Giscus GitHub App appears installed for $owner/$reponame" || warn "Could not confirm Giscus app installation. Visit https://github.com/apps/giscus → Configure → grant access to $owner/$reponame."

echo
if (( failures == 0 )); then
  ok "All checks passed."
  echo "Preview locally: bundle exec jekyll clean && JEKYLL_ENV=development bundle exec jekyll serve --livereload"
  exit 0
else
  bad "Found $failures issue(s). Review messages above, fix, and re-run."
  exit 1
fi

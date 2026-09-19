#!/usr/bin/env bash

set -Eeuo pipefail

readonly PRODUCTION_DIR="/home/vcfinsider_web/vcfinsider.com"
readonly PRODUCTION_DEPLOYMENT_DIR="/home/vcfinsider_web/deployments/vcfinsider"
readonly STAGING_DIR="/home/vcfinsider_web/staging.vcfinsider.com"
readonly STAGING_DEPLOYMENT_DIR="/home/vcfinsider_web/deployments/vcfinsider-staging"

TARGET_DIR=""
DEPLOYMENT_DIR=""

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

select_target() {
  case "$1" in
    production)
      TARGET_DIR="$PRODUCTION_DIR"
      DEPLOYMENT_DIR="$PRODUCTION_DEPLOYMENT_DIR"
      ;;
    staging)
      TARGET_DIR="$STAGING_DIR"
      DEPLOYMENT_DIR="$STAGING_DEPLOYMENT_DIR"
      ;;
    *)
      die "Unsupported deployment target: $1"
      ;;
  esac

  readonly TARGET_DIR DEPLOYMENT_DIR
}

assert_safe_paths() {
  local target_real home_real

  home_real="$(realpath "$HOME")"
  target_real="$(realpath "$TARGET_DIR")"

  [[ "$home_real" == "/home/vcfinsider_web" ]] || die "Unexpected home directory: $home_real"
  [[ "$target_real" == "$TARGET_DIR" ]] || die "Unexpected target path: $target_real"
  [[ "$TARGET_DIR" == "$PRODUCTION_DIR" || "$TARGET_DIR" == "$STAGING_DIR" ]] || die "Unapproved target path"
  [[ "$DEPLOYMENT_DIR" == "$PRODUCTION_DEPLOYMENT_DIR" || "$DEPLOYMENT_DIR" == "$STAGING_DEPLOYMENT_DIR" ]] || die "Unapproved deployment path"
  [[ "$TARGET_DIR" != "/" && "$TARGET_DIR" != "$HOME" ]] || die "Unsafe target path"
}

validate_release_id() {
  [[ "$1" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}$ ]] || die "Invalid release ID: $1"
}

validate_sha() {
  [[ "$1" =~ ^[0-9a-f]{40}$ ]] || die "Invalid Git commit SHA: $1"
}

validate_archive() {
  local archive="$1"

  [[ -f "$archive" && ! -L "$archive" ]] || die "Release archive is missing or unsafe: $archive"

  if tar -tzf "$archive" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    die "Release archive contains an unsafe path"
  fi
}

deploy_release() {
  local target="$1"
  local release_id="$2"
  local git_sha="$3"
  local archive="$4"
  local release_dir="$DEPLOYMENT_DIR/releases/$release_id"
  local backup_dir="$DEPLOYMENT_DIR/backups/$release_id"
  local metadata_tmp="$DEPLOYMENT_DIR/.current-release.tmp"

  validate_release_id "$release_id"
  validate_sha "$git_sha"
  validate_archive "$archive"

  [[ "$archive" == "$DEPLOYMENT_DIR/incoming/$release_id.tar.gz" ]] || die "Unexpected archive path"
  [[ ! -e "$release_dir" ]] || die "Release directory already exists: $release_dir"
  [[ ! -e "$backup_dir" ]] || die "Backup directory already exists: $backup_dir"

  mkdir -p "$DEPLOYMENT_DIR/releases" "$DEPLOYMENT_DIR/backups"
  mkdir "$release_dir" "$backup_dir"

  tar -xzf "$archive" -C "$release_dir"
  [[ -f "$release_dir/index.html" && ! -L "$release_dir/index.html" ]] || die "Staged release has no safe index.html"

  printf 'Backing up %s to %s\n' "$TARGET_DIR" "$backup_dir"
  rsync -a --delete "$TARGET_DIR/" "$backup_dir/"

  printf 'Promoting %s to %s\n' "$release_dir" "$TARGET_DIR"
  if ! rsync -a --delete \
      --exclude='/.dh-diag' \
      --exclude='/.well-known/' \
      --exclude='/.htaccess' \
      "$release_dir/" "$TARGET_DIR/"; then
    printf 'Promotion failed; attempting automatic restore from %s\n' "$backup_dir" >&2
    rsync -a --delete \
      --exclude='/.dh-diag' \
      --exclude='/.well-known/' \
      --exclude='/.htaccess' \
      "$backup_dir/" "$TARGET_DIR/" || die "Promotion and automatic restore both failed"
    die "Promotion failed; the previous $target copy was restored"
  fi

  {
    printf 'target=%s\n' "$target"
    printf 'release_id=%s\n' "$release_id"
    printf 'git_sha=%s\n' "$git_sha"
    printf 'deployed_utc=%s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  } >"$metadata_tmp"
  chmod 600 "$metadata_tmp"
  mv -f "$metadata_tmp" "$DEPLOYMENT_DIR/current-release"

  rm -f "$archive"
  printf '%s deployment completed for release %s (%s)\n' "$target" "$release_id" "$git_sha"
  printf 'Backup retained at %s\n' "$backup_dir"
}

main() {
  local action="${1:-}"
  local target="${2:-}"

  require_command realpath
  require_command rsync
  require_command tar
  require_command grep
  select_target "$target"
  assert_safe_paths

  case "$action" in
    deploy)
      [[ "$#" -eq 5 ]] || die "Usage: $0 deploy TARGET RELEASE_ID GIT_SHA ARCHIVE"
      deploy_release "$target" "$3" "$4" "$5"
      ;;
    *)
      die "Unsupported action: ${action:-<empty>}"
      ;;
  esac
}

main "$@"

#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

WIPE_CACHE=0
NO_SPINNER=0
NO_CLEAR=0

for arg in "$@"; do
  case "$arg" in
  --wipe-cache) WIPE_CACHE=1 ;;
  --no-spinner) NO_SPINNER=1 ;;
  --no-clear) NO_CLEAR=1 ;;
  -h | --help)
    cat <<'EOF'
Usage: brew-maintenance.sh [options]
  --wipe-cache   Delete everything in $(brew --cache) after cleanup
  --no-spinner   Disable spinner
  --no-clear     Don't clear screen
EOF
    exit 0
    ;;
  esac
done

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  GREEN=$'\033[32m'
  BLUE=$'\033[34m'
  NC=$'\033[0m'
else
  BOLD=""
  DIM=""
  GREEN=""
  BLUE=""
  NC=""
  NO_SPINNER=1
fi
readonly BOLD DIM GREEN BLUE NC

SPINNER_PID=""
PACKAGES_UPDATED=0
PACKAGES_UPGRADED=0
PACKAGES_REMOVED=0

start_spinner() {
  [[ "$NO_SPINNER" -eq 1 ]] && return 0
  local status_text="$1"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

  {
    while true; do
      for frame in "${frames[@]}"; do
        printf "\r%s%s%s %s" "$DIM" "$frame" "$NC" "$status_text"
        sleep 0.08
      done
    done
  } &
  SPINNER_PID=$!
}

stop_spinner() {
  [[ "$NO_SPINNER" -eq 1 ]] && return 0
  if [[ -n "${SPINNER_PID:-}" ]]; then
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
  fi
  printf "\r\033[K"
}

log_header() { printf "\n${BOLD}%s${NC}\n" "$1"; }
log_success() { printf "${GREEN}✓${NC} %s\n" "$1"; }
log_step() { printf "${BLUE}→${NC} %s\n" "$1"; }
log_muted() { printf "${DIM}%s${NC}\n" "$1"; }

print_summary() {
  log_header "Summary"
  printf "  ${DIM}Updated:${NC} %d  ${DIM}Upgraded:${NC} %d  ${DIM}Removed:${NC} %d\n" \
    "$PACKAGES_UPDATED" "$PACKAGES_UPGRADED" "$PACKAGES_REMOVED"
}

handle_exit() {
  stop_spinner
  printf "\n"
}

# Avoid double-firing
trap handle_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

verify_homebrew_installed() {
  log_step "Checking installation"
  if ! command -v brew >/dev/null 2>&1; then
    log_muted "Error: Homebrew not found"
    exit 1
  fi
  log_success "Ready"
}

update_package_definitions() {
  log_step "Updating Homebrew"
  start_spinner "Fetching latest package definitions"

  local out=""
  if out="$(brew update 2>&1)"; then
    stop_spinner
    PACKAGES_UPDATED="$(grep -c "Updated" <<<"$out" || true)"
    log_success "Updated"
  else
    stop_spinner
    log_muted "Update failed"
    exit 1
  fi
}

upgrade_installed_packages() {
  log_step "Upgrading packages"
  start_spinner "Checking outdated packages"

  local outdated_list=""
  outdated_list="$(brew outdated --quiet 2>/dev/null || true)"
  stop_spinner

  if [[ -z "$outdated_list" ]]; then
    PACKAGES_UPGRADED=0
    log_success "Already up to date"
    return 0
  fi

  PACKAGES_UPGRADED="$(wc -l <<<"$outdated_list" | tr -d ' ')"

  start_spinner "Installing available upgrades"
  if brew upgrade >/dev/null 2>&1; then
    stop_spinner
    log_success "Upgraded $PACKAGES_UPGRADED"
  else
    stop_spinner
    log_muted "Upgrade failed"
    exit 1
  fi
}

cleanup_system() {
  log_step "Cleaning up"
  start_spinner "Removing outdated versions and cache"

  brew cleanup -s >/dev/null 2>&1 || true

  local ar_out=""
  ar_out="$(brew autoremove 2>&1 || true)"
  if [[ -n "$ar_out" ]]; then
    PACKAGES_REMOVED="$(grep -cE "^(Removing formula|Uninstalling)" <<<"$ar_out" || true)"
    [[ "$PACKAGES_REMOVED" =~ ^[0-9]+$ ]] || PACKAGES_REMOVED=0
  fi

  if [[ "$WIPE_CACHE" -eq 1 ]]; then
    local cache_path=""
    cache_path="$(brew --cache 2>/dev/null || true)"
    if [[ -n "${cache_path:-}" && -d "$cache_path" ]]; then
      find "$cache_path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    fi
  fi

  stop_spinner
  log_success "Clean"
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "Homebrew Maintenance"
  printf "\n"

  verify_homebrew_installed
  update_package_definitions
  upgrade_installed_packages
  cleanup_system

  printf "\n"
  print_summary
  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

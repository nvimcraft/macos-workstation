#!/usr/bin/env bash

# nvimcraft macOS homebrew maintenance script

set -euo pipefail

readonly BOLD=$'\033[1m'
readonly DIM=$'\033[2m'
readonly GREEN=$'\033[32m'
readonly BLUE=$'\033[34m'
readonly NC=$'\033[0m'

SPINNER_PID=""
PACKAGES_UPDATED=0
PACKAGES_UPGRADED=0
PACKAGES_REMOVED=0

start_spinner() {
  local status_text="$1"
  local spinner_frames="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

  {
    while true; do
      for ((i = 0; i < ${#spinner_frames}; i++)); do
        printf "\r${DIM}${spinner_frames:$i:1}${NC} %s" "$status_text"
        sleep 0.08
      done
    done
  } &
  SPINNER_PID=$!
}

stop_spinner() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null && wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
  fi
  printf "\r\033[K"
}

log_header() {
  printf "\n${BOLD}%s${NC}\n" "$1"
}

log_success() {
  printf "${GREEN}✓${NC} %s\n" "$1"
}

log_step() {
  printf "${BLUE}→${NC} %s\n" "$1"
}

log_muted() {
  printf "${DIM}%s${NC}\n" "$1"
}

print_summary() {
  log_header "Summary"
  printf "  ${DIM}Updated:${NC} %d  ${DIM}Upgraded:${NC} %d  ${DIM}Removed:${NC} %d\n" \
    "$PACKAGES_UPDATED" "$PACKAGES_UPGRADED" "$PACKAGES_REMOVED"
}

handle_exit() {
  stop_spinner
  printf "\n"
}

trap handle_exit EXIT INT TERM

verify_homebrew_installed() {
  log_step "Checking installation"

  if ! command -v brew &>/dev/null; then
    log_muted "Error: Homebrew not found"
    exit 1
  fi

  log_success "Ready"
}

update_package_definitions() {
  log_step "Updating Homebrew"
  start_spinner "Fetching latest package definitions"

  local brew_output
  if brew_output=$(brew update 2>&1); then
    stop_spinner
    PACKAGES_UPDATED=$(echo "$brew_output" | grep -c "Updated " 2>/dev/null || echo "0")
    [[ "$PACKAGES_UPDATED" =~ ^[0-9]+$ ]] || PACKAGES_UPDATED=0
    log_success "Updated"
  else
    stop_spinner
    log_muted "Update failed"
    exit 1
  fi
}

upgrade_installed_packages() {
  log_step "Upgrading packages"
  start_spinner "Installing available upgrades"

  local brew_output
  if brew_output=$(brew upgrade 2>&1); then
    stop_spinner
    PACKAGES_UPGRADED=$(echo "$brew_output" | grep -c "==> Upgrading " 2>/dev/null || echo "0")
    [[ "$PACKAGES_UPGRADED" =~ ^[0-9]+$ ]] || PACKAGES_UPGRADED=0

    if [[ "$PACKAGES_UPGRADED" -eq 0 ]]; then
      log_success "Already up to date"
    else
      log_success "Upgraded $PACKAGES_UPGRADED"
    fi
  else
    stop_spinner
    log_muted "Upgrade failed"
    exit 1
  fi
}

cleanup_system() {
  log_step "Cleaning up"
  start_spinner "Removing outdated versions"

  # Remove old package versions and cached downloads
  brew cleanup -s >/dev/null 2>&1 || true

  # Remove orphaned dependencies
  local brew_output
  if brew_output=$(brew autoremove -q 2>&1); then
    PACKAGES_REMOVED=$(echo "$brew_output" | grep -c "Uninstalling " 2>/dev/null || echo "0")
    [[ "$PACKAGES_REMOVED" =~ ^[0-9]+$ ]] || PACKAGES_REMOVED=0
  fi

  # Clear download cache
  local cache_path="${HOMEBREW_CACHE:-$HOME/Library/Caches/Homebrew}"

  if [[ -d "$cache_path" ]]; then
    find "$cache_path" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
  fi

  stop_spinner
  log_success "Clean"
}

main() {
  clear
  log_header "Homebrew Maintenance"
  printf "\n"

  verify_homebrew_installed
  update_package_definitions
  upgrade_installed_packages
  cleanup_system

  printf "\n"
  print_summary
  printf "\n%s✓%s %sComplete%s\n" \
    "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

NO_SPINNER=0
NO_CLEAR=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
  --no-spinner) NO_SPINNER=1 ;;
  --no-clear) NO_CLEAR=1 ;;
  --dry-run) DRY_RUN=1 ;;
  -h | --help)
    cat <<'EOF'
Usage: apps-rollback.sh [options]
  --dry-run      Show what would be uninstalled, but do not uninstall anything
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
APPS_REMOVED=0
APPS_SKIPPED=0

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
  printf "  ${DIM}Removed:${NC} %d  ${DIM}Skipped:${NC} %d\n" \
    "$APPS_REMOVED" "$APPS_SKIPPED"
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

  if [[ "$DRY_RUN" -eq 1 ]]; then
    stop_spinner
    log_success "Dry run"
    return 0
  fi

  if brew update >/dev/null 2>&1; then
    stop_spinner
    log_success "Updated"
  else
    stop_spinner
    log_muted "Update failed"
    exit 1
  fi
}

uninstall_gui_applications() {
  local gui_application_names=(
    chatgpt
    discord
    docker
    keycastr
    microsoft-teams
    raycast
    spotify
    thebrowsercompany-dia
    wezterm
    zoom
  )

  log_step "Uninstalling GUI applications"

  for application_name in "${gui_application_names[@]}"; do
    if ! brew list --cask "$application_name" >/dev/null 2>&1; then
      ((APPS_SKIPPED += 1))
      log_success "Already removed: $application_name"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      ((APPS_REMOVED += 1))
      log_muted "DRY-RUN: would uninstall $application_name"
      continue
    fi

    start_spinner "Uninstalling $application_name"
    if brew uninstall --cask "$application_name" >/dev/null 2>&1; then
      stop_spinner
      ((APPS_REMOVED += 1))
      log_success "Removed $application_name"
    else
      stop_spinner
      ((APPS_SKIPPED += 1))
      log_muted "Failed to uninstall $application_name"
    fi
  done
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "GUI Applications Rollback"
  printf "\n"

  verify_homebrew_installed
  update_package_definitions
  uninstall_gui_applications

  printf "\n"
  print_summary
  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

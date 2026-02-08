#!/usr/bin/env bash

# nvimcraft macOS GUI applications environment setup

set -euo pipefail

readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly GREEN='\033[32m'
readonly BLUE='\033[34m'
readonly YELLOW='\033[33m'
readonly NC='\033[0m'

SPINNER_PID=""
APPS_INSTALLED=0
APPS_SKIPPED=0

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

log_skip() {
  printf "${YELLOW}○${NC} %s\n" "$1"
}

log_muted() {
  printf "${DIM}%s${NC}\n" "$1"
}

print_summary() {
  log_header "Summary"
  printf "  ${DIM}Installed:${NC} %d  ${DIM}Skipped:${NC} %d\n" \
    "$APPS_INSTALLED" "$APPS_SKIPPED"
}

handle_exit() {
  stop_spinner
  printf "\n"
}

trap handle_exit EXIT INT TERM

verify_homebrew_installed() {
  log_step "Checking Homebrew installation"

  if ! command -v brew &>/dev/null; then
    log_muted "Error: Homebrew not found"
    exit 1
  fi

  log_success "Ready"
}

update_package_definitions() {
  log_step "Updating Homebrew"
  start_spinner "Fetching latest package definitions"

  if brew update >/dev/null 2>&1; then
    stop_spinner
    log_success "Updated"
  else
    stop_spinner
    log_muted "Update failed"
    exit 1
  fi
}

install_gui_applications() {
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

  log_step "Installing GUI applications"

  for application_name in "${gui_application_names[@]}"; do
    if brew list --cask "$application_name" &>/dev/null; then
      ((APPS_SKIPPED++))
      log_skip "Already installed: $application_name"
    else
      start_spinner "Installing $application_name"
      if brew install --cask "$application_name" >/dev/null 2>&1; then
        stop_spinner
        ((APPS_INSTALLED++))
        log_success "Installed $application_name"
      else
        stop_spinner
        log_muted "Failed to install $application_name"
      fi
    fi
  done
}

main() {
  clear
  log_header "GUI Applications Setup"
  printf "\n"

  verify_homebrew_installed
  update_package_definitions
  install_gui_applications

  printf "\n"
  print_summary
  printf "\n%s✓%s %sComplete%s\n" \
    "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

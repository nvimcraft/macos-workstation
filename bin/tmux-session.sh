#!/usr/bin/env bash

# nvimcraft macOS tmux session setup script

set -euo pipefail

readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly GREEN='\033[32m'
readonly BLUE='\033[34m'
readonly YELLOW='\033[33m'
readonly NC='\033[0m'

readonly SESSION_NAME="dev"

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

verify_tmux_installed() {
  log_step "Checking TMUX installation"

  if ! command -v tmux >/dev/null 2>&1; then
    log_muted "Error: TMUX not found"
    exit 1
  fi

  log_success "Ready"
}

create_tmux_session() {
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log_skip "Session '$SESSION_NAME' already exists"
    return
  fi

  log_step "Creating TMUX session"

  tmux new-session -d -s "$SESSION_NAME" -n main

  main_pane_id="$(tmux display-message -t "$SESSION_NAME":main -p '#{pane_id}')"

  tmux split-window -h -p 10 -t "$main_pane_id"
  tmux split-window -v -p 10 -t "$main_pane_id"
  tmux select-pane -t "$main_pane_id"

  log_success "Created session '$SESSION_NAME'"
}

attach_to_tmux_session() {
  tmux attach-session -t "$SESSION_NAME"
}

main() {
  clear
  log_header "TMUX Session Manager"
  printf "\n"

  verify_tmux_installed
  create_tmux_session
  attach_to_tmux_session
}

main "$@"

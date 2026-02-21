#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

SESSION_NAME="dev"
NO_CLEAR=0

for arg in "$@"; do
  case "$arg" in
  --session=*)
    SESSION_NAME="${arg#--session=}"
    ;;
  --no-clear)
    NO_CLEAR=1
    ;;
  -h | --help)
    cat <<'EOF'
Usage: tmux-session.sh [options]
  --session=NAME  Session name (default: dev)
  --no-clear      Don't clear screen
EOF
    exit 0
    ;;
  esac
done
readonly SESSION_NAME

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
fi
readonly BOLD DIM GREEN BLUE NC

log_header() { printf "\n${BOLD}%s${NC}\n" "$1"; }
log_success() { printf "${GREEN}✓${NC} %s\n" "$1"; }
log_step() { printf "${BLUE}→${NC} %s\n" "$1"; }
log_muted() { printf "${DIM}%s${NC}\n" "$1"; }

handle_exit() { printf "\n"; }

trap handle_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

verify_tmux_installed() {
  log_step "Checking installation"
  if ! command -v tmux >/dev/null 2>&1; then
    log_muted "Error: tmux not found"
    exit 1
  fi
  log_success "Ready"
}

ensure_tmux_session() {
  # has-session exits 0 if session exists, non-zero if missing
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log_success "Session '$SESSION_NAME' already exists"
    return 0
  fi

  log_step "Creating session"
  tmux new-session -d -s "$SESSION_NAME" -n main

  local main_pane_id=""
  main_pane_id="$(tmux display-message -t "$SESSION_NAME":main -p '#{pane_id}')"

  tmux split-window -h -p 10 -t "$main_pane_id"
  tmux split-window -v -p 10 -t "$main_pane_id"
  tmux select-pane -t "$main_pane_id"

  log_success "Created session '$SESSION_NAME'"
}

open_tmux_session() {
  log_step "Opening session"

  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION_NAME"
  else
    tmux attach-session -t "$SESSION_NAME"
  fi
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "TMUX Session"
  printf "\n"

  verify_tmux_installed
  ensure_tmux_session
  open_tmux_session

  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

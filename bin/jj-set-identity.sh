#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

DRY_RUN=0
NO_CLEAR=0

for arg in "$@"; do
  case "$arg" in
  --dry-run) DRY_RUN=1 ;;
  --no-clear) NO_CLEAR=1 ;;
  -h | --help)
    cat <<'EOF'
Usage: jj-set-identity.sh [options]
  --dry-run        Show what would be set, but do not modify repo config
  --no-clear       Don't clear screen
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

verify_jj_installed() {
  log_step "Checking installation"
  if ! command -v jj >/dev/null 2>&1; then
    log_muted "Error: jj not found"
    exit 127
  fi
  log_success "Ready"
}

verify_in_jj_repo() {
  log_step "Checking repository"
  if ! jj root >/dev/null 2>&1; then
    log_muted "Error: Not in a jj repository"
    exit 1
  fi
  log_success "Ready"
}

set_repo_identity() {
  log_step "Setting identity"

  local repo_path=""
  repo_path="$(pwd -P)"

  local name="nvimcraft"
  local email=""
  local host=""

  if [[ "$repo_path" == *"/gitea/"* ]]; then
    host="Gitea"
    email="nvimcraft@noreply.gitea.com"
  elif [[ "$repo_path" == *"/github/"* ]]; then
    host="GitHub"
    email="260064684+nvimcraft@users.noreply.github.com"
  else
    log_muted "No matching git host pattern found"
    exit 1
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: jj config set --repo user.name \"$name\""
    log_muted "DRY-RUN: jj config set --repo user.email \"$email\""
    log_success "Dry run"
    return 0
  fi

  jj config set --repo user.name "$name"
  jj config set --repo user.email "$email"
  log_success "Set jj identity to $host"
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "JJ Identity"
  printf "\n"

  verify_jj_installed
  verify_in_jj_repo
  set_repo_identity

  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

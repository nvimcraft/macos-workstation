#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

NO_CLEAR=0
NO_PROMPT=1
FORCE=0

for arg in "$@"; do
  case "$arg" in
  --no-clear) NO_CLEAR=1 ;;
  --interactive) NO_PROMPT=0 ;;
  --force) FORCE=1 ;;
  -h | --help)
    cat <<'EOF'
Usage: ssh-bootstrap.sh [options]
  --force         Allow writing files even if ~/.ssh material exists (backs up first)
  --interactive   Run ssh-keygen interactively (prompts for passphrase)
  --no-clear      Don't clear screen
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

readonly SSH_DIR="$HOME/.ssh"
readonly KEY_GITHUB="$SSH_DIR/id_ed25519_github"
readonly KEY_GITEA="$SSH_DIR/id_ed25519_gitea"
readonly SSH_CONFIG="$SSH_DIR/config"

log_header() { printf "\n${BOLD}%s${NC}\n" "$1"; }
log_success() { printf "${GREEN}✓${NC} %s\n" "$1"; }
log_step() { printf "${BLUE}→${NC} %s\n" "$1"; }
log_muted() { printf "${DIM}%s${NC}\n" "$1"; }

handle_exit() { printf "\n"; }

trap handle_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

verify_ssh_tools_installed() {
  log_step "Checking installation"
  if ! command -v ssh-keygen >/dev/null 2>&1; then
    log_muted "Error: ssh-keygen not found"
    exit 1
  fi
  log_success "Ready"
}

backup_if_exists() {
  local path="$1"
  [[ -e "$path" ]] || return 0

  local backup
  backup="${path}.bak.$(date +%s)"

  mv -- "$path" "$backup"
  log_muted "Backed up $(basename "$path") -> $(basename "$backup")"
}

prepare_ssh_directory() {
  log_step "Preparing ~/.ssh"
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  log_success "Ready"
}

generate_keys() {
  log_step "Generating keys"

  if [[ "$NO_PROMPT" -eq 1 ]]; then
    # -N "" avoids passphrase prompts (non-interactive).
    ssh-keygen -q -t ed25519 -f "$KEY_GITHUB" -C "nvimcraft@github" -N ""
    ssh-keygen -q -t ed25519 -f "$KEY_GITEA" -C "nvimcraft@gitea" -N ""
  else
    ssh-keygen -t ed25519 -f "$KEY_GITHUB" -C "nvimcraft@github"
    ssh-keygen -t ed25519 -f "$KEY_GITEA" -C "nvimcraft@gitea"
  fi

  log_success "Generated"
}

write_ssh_config() {
  log_step "Writing config"

  cat <<'EOF' >"$SSH_CONFIG"
Host github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github
  IdentitiesOnly yes

Host gitea.com
  User git
  IdentityFile ~/.ssh/id_ed25519_gitea
  IdentitiesOnly yes
EOF

  log_success "Written"
}

set_permissions() {
  log_step "Setting permissions"

  chmod 600 "$SSH_CONFIG"
  chmod 600 "$SSH_DIR"/id_ed25519_*
  chmod 644 "$SSH_DIR"/id_ed25519_*.pub

  log_success "Set"
}

print_next_steps() {
  printf "\n"
  log_success "Generated per-host SSH keys and ssh_config entries"
  log_muted "Add these public keys to their respective services:"

  printf "  GitHub: %s\n" "$(cat "${KEY_GITHUB}.pub")"
  printf "  Gitea : %s\n" "$(cat "${KEY_GITEA}.pub")"
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "SSH Bootstrap"
  printf "\n"

  verify_ssh_tools_installed

  if [[ -e "$KEY_GITHUB" || -e "$KEY_GITEA" || -e "$SSH_CONFIG" ]]; then
    if [[ "$FORCE" -eq 0 ]]; then
      log_muted "Error: Refusing to overwrite existing ~/.ssh material"
      log_muted "Tip: re-run with --force to back up and replace"
      exit 1
    fi
    log_step "Backing up existing files"
    backup_if_exists "$KEY_GITHUB"
    backup_if_exists "${KEY_GITHUB}.pub"
    backup_if_exists "$KEY_GITEA"
    backup_if_exists "${KEY_GITEA}.pub"
    backup_if_exists "$SSH_CONFIG"
    log_success "Backed up"
  fi

  prepare_ssh_directory
  generate_keys
  write_ssh_config
  set_permissions

  print_next_steps

  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

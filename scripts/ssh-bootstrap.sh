#!/usr/bin/env bash

# Establish per-host SSH identities for GitHub and Gitea on a fresh machine.
# This script never writes private key material to git; it only orchestrates
# local key generation and a stable ssh_config layout.

set -euo pipefail

readonly BOLD=$'\033[1m'
readonly GREEN=$'\033[32m'
readonly YELLOW=$'\033[33m'
readonly RED=$'\033[31m'
readonly NC=$'\033[0m'

main() {
  # Refuse to run if ~/.ssh already contains host-specific keys, to avoid
  # silently overwriting existing credentials. This script is intended for
  # first-time bootstrap on a new machine.
  if [[ -e "$HOME/.ssh/id_ed25519_github" || -e "$HOME/.ssh/id_ed25519_gitea" ]]; then
    printf "%s✗%s %sRefusing to overwrite existing SSH keys%s\n" \
      "$RED" "$NC" "$BOLD" "$NC"
    exit 1
  fi

  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_github" -C "nvimcraft@github"
  ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519_gitea" -C "nvimcraft@gitea"

  # Define a per-host ssh_config surface so git can route the correct key
  # purely based on hostname, independent of environment variables.
  cat <<'EOF' >"$HOME/.ssh/config"
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_github

Host gitea.com
  HostName gitea.com
  User git
  IdentityFile ~/.ssh/id_ed25519_gitea
EOF

  chmod 600 "$HOME/.ssh"/id_ed25519_*
  chmod 644 "$HOME/.ssh"/id_ed25519_*.pub

  printf "\n%s✓%s %sGenerated per-host SSH keys and ssh_config entries%s\n" \
    "$GREEN" "$NC" "$BOLD" "$NC"
  printf "%s○%s %sAdd these public keys to their respective services:%s\n" \
    "$YELLOW" "$NC" "$BOLD" "$NC"
  printf "  GitHub: %s\n" "$(cat "$HOME/.ssh/id_ed25519_github.pub")"
  printf "  Gitea : %s\n" "$(cat "$HOME/.ssh/id_ed25519_gitea.pub")"
}

main "$@"

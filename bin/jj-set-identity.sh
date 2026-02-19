#!/usr/bin/env bash

# Establish a jj user identity policy that mirrors gitdir-scoped git config.
# This is an explicit, per-repo setter invoked by the maintainer, not magic
# that silently mutates config on every shell entry.

set -euo pipefail

readonly BOLD=$'\033[1m'
readonly GREEN=$'\033[32m'
readonly YELLOW=$'\033[33m'
readonly RED=$'\033[31m'
readonly NC=$'\033[0m'

main() {
  # Refuse to run outside a jj repository to avoid silently writing
  # config into unexpected locations. This script is deliberately
  # opinionated: it only ever touches the active repo.
  if ! jj log -r '@' >/dev/null 2>&1; then
    printf "%s✗%s %sNot in a jj repository%s\n" \
      "$RED" "$NC" "$BOLD" "$NC"
    exit 1
  fi

  # Derive identity from the repository’s location on disk rather than
  # from remote URLs. This keeps the rule surface simple and mirrors the
  # gitdir-based strategy used in .gitconfig.
  if [[ "$PWD" == *"/gitea/"* ]]; then
    jj config set --repo user.name "nvimcraft"
    jj config set --repo user.email "nvimcraft@noreply.gitea.com"
    printf "%s✓%s %sSet jj identity to Gitea%s\n" \
      "$GREEN" "$NC" "$BOLD" "$NC"
  elif [[ "$PWD" == *"/github/"* ]]; then
    jj config set --repo user.name "nvimcraft"
    jj config set --repo user.email "260064684+nvimcraft@users.noreply.github.com"
    printf "%s✓%s %sSet jj identity to GitHub%s\n" \
      "$GREEN" "$NC" "$BOLD" "$NC"
  else
    # Fail loudly when the path does not match a known host namespace so
    # we do not accidentally leave a repo with a stale or incorrect identity.
    printf "%s○%s %sNo matching git host pattern found%s\n" \
      "$YELLOW" "$NC" "$BOLD" "$NC"
    exit 1
  fi
}

main "$@"

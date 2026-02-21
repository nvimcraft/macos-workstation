#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

NO_SPINNER=0
NO_CLEAR=0
DRY_RUN=0
DEBUG_FLAG=0
ASSUME_YES=0

DOTFILES_DIRECTORY="${DOTFILES_DIRECTORY:-$HOME/dotfiles-macos}"
WORKSTATION_DIRECTORY="${WORKSTATION_DIRECTORY:-$HOME/Developer/projects/github/macos-workstation}"

REMOVE_BREW_PACKAGES="${REMOVE_BREW_PACKAGES:-1}"
REMOVE_NERD_FONTS="${REMOVE_NERD_FONTS:-1}"
REMOVE_DOTFILES_REPO="${REMOVE_DOTFILES_REPO:-1}"
REMOVE_WORKSTATION_REPO="${REMOVE_WORKSTATION_REPO:-0}"
RUN_BREW_CLEANUP="${RUN_BREW_CLEANUP:-1}"

for arg in "$@"; do
  case "$arg" in
  --no-spinner) NO_SPINNER=1 ;;
  --no-clear) NO_CLEAR=1 ;;
  --dry-run) DRY_RUN=1 ;;
  --debug) DEBUG_FLAG=1 ;;
  -y | --yes) ASSUME_YES=1 ;;

  --keep-brew) REMOVE_BREW_PACKAGES=0 ;;
  --keep-fonts) REMOVE_NERD_FONTS=0 ;;
  --keep-dotfiles-repo) REMOVE_DOTFILES_REPO=0 ;;
  --remove-workstation-repo) REMOVE_WORKSTATION_REPO=1 ;;
  --no-brew-cleanup) RUN_BREW_CLEANUP=0 ;;

  -h | --help)
    cat <<'EOF'
Usage: dev-rollback.sh [options]
  --dry-run                 Show what would be done, but do not make changes
  --no-spinner              Disable spinner
  --no-clear                Don't clear screen
  --debug                   Enable shell tracing (set -x)
  -y, --yes                 Skip confirmation prompt

  --keep-brew               Do not uninstall Homebrew formulae from bootstrap list
  --keep-fonts              Do not uninstall Nerd Font casks from bootstrap list
  --keep-dotfiles-repo       Do not delete local dotfiles repo directory
  --remove-workstation-repo  Delete local workstation repo directory
  --no-brew-cleanup          Skip brew autoremove/cleanup
EOF
    exit 0
    ;;
  esac
done

if [[ "${DEBUG:-0}" == "1" || "$DEBUG_FLAG" -eq 1 ]]; then
  set -x
fi

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
readonly DOTFILES_DIRECTORY WORKSTATION_DIRECTORY DRY_RUN

SPINNER_PID=""
FORMULAE_REMOVED=0
CASKS_REMOVED=0
SYMLINKS_REMOVED=0

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

handle_exit() {
  stop_spinner
  printf "\n"
}

trap handle_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: $*"
    return 0
  fi
  "$@"
}

require_macos() {
  log_step "Checking platform"
  if [[ "$(uname -s)" != "Darwin" ]]; then
    log_muted "Error: This rollback script is intended for macOS (Darwin) only"
    exit 1
  fi
  log_success "Ready"
}

print_summary() {
  log_header "Summary"
  printf "  ${DIM}Formulae removed:${NC} %d  ${DIM}Casks removed:${NC} %d  ${DIM}Symlinks removed:${NC} %d\n" \
    "$FORMULAE_REMOVED" "$CASKS_REMOVED" "$SYMLINKS_REMOVED"
}

confirm_rollback_operation() {
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    log_step "Confirmation"
    log_success "Skipped (--yes)"
    return 0
  fi

  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "macOS Development Environment Rollback"
  printf "\n"

  log_muted "Warning: This will remove Stow-managed dotfile symlinks and optionally uninstall Homebrew packages from the bootstrap list."
  printf "\n%sPlanned actions:%s\n" "$DIM" "$NC"
  printf "  %s•%s Remove Stow-managed symlinks from %s\n" "$DIM" "$NC" "$HOME"
  if [[ "$REMOVE_BREW_PACKAGES" == "1" ]]; then
    printf "  %s•%s Uninstall Homebrew formulae from bootstrap list\n" "$DIM" "$NC"
  fi
  if [[ "$REMOVE_NERD_FONTS" == "1" ]]; then
    printf "  %s•%s Uninstall Nerd Font casks from bootstrap list\n" "$DIM" "$NC"
  fi
  if [[ "$RUN_BREW_CLEANUP" == "1" ]]; then
    printf "  %s•%s Run brew autoremove and brew cleanup\n" "$DIM" "$NC"
  fi
  if [[ "$REMOVE_DOTFILES_REPO" == "1" ]]; then
    printf "  %s•%s Remove local repo at %s\n" "$DIM" "$NC" "$DOTFILES_DIRECTORY"
  fi
  if [[ "$REMOVE_WORKSTATION_REPO" == "1" ]]; then
    printf "  %s•%s Remove local repo at %s\n" "$DIM" "$NC" "$WORKSTATION_DIRECTORY"
  fi
  printf "\n"

  read -rp "$(printf "%sProceed? (y/N):%s " "$BLUE" "$NC")" ans
  if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
    log_success "Cancelled"
    exit 0
  fi

  printf "\n"
}

remove_dotfiles_symlinks() {
  log_step "Removing dotfiles symlinks"

  if [[ ! -d "$DOTFILES_DIRECTORY" ]]; then
    log_success "No dotfiles directory"
    return 0
  fi

  if ! command -v stow >/dev/null 2>&1; then
    log_success "stow not found; skipping"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: (cd \"$DOTFILES_DIRECTORY\" && stow --target \"$HOME\" -D .)"
    ((SYMLINKS_REMOVED += 1))
    log_success "Dry run"
    return 0
  fi

  start_spinner "Removing Stow symlinks"
  pushd "$DOTFILES_DIRECTORY" >/dev/null 2>&1 || {
    stop_spinner
    log_muted "Error: Could not access dotfiles directory"
    return 0
  }

  if stow --target "$HOME" -D . >/dev/null 2>&1; then
    ((SYMLINKS_REMOVED += 1))
    stop_spinner
    log_success "Removed"
  else
    stop_spinner
    log_success "Nothing to remove"
  fi

  popd >/dev/null 2>&1 || true
}

uninstall_homebrew_formulae() {
  log_step "Uninstalling Homebrew formulae"

  if [[ "$REMOVE_BREW_PACKAGES" != "1" ]]; then
    log_success "Skipped"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    log_success "Homebrew not found; skipped"
    return 0
  fi

  local formulae=(
    stow node git gh neovim tmux
    go python
    ripgrep bat eza tree tlrc zoxide delta
    powerlevel10k zsh-autosuggestions zsh-syntax-highlighting
  )

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: brew uninstall ${formulae[*]}"
    log_success "Dry run"
    return 0
  fi

  start_spinner "Removing formulae"
  local removed=0
  for f in "${formulae[@]}"; do
    if brew list "$f" >/dev/null 2>&1; then
      if brew uninstall "$f" >/dev/null 2>&1; then
        ((removed += 1))
      fi
    fi
  done
  stop_spinner

  ((FORMULAE_REMOVED += removed))
  if ((removed == 0)); then
    log_success "Nothing to remove"
  else
    log_success "Removed $removed"
  fi
}

uninstall_nerd_fonts() {
  log_step "Uninstalling Nerd Font casks"

  if [[ "$REMOVE_NERD_FONTS" != "1" ]]; then
    log_success "Skipped"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    log_success "Homebrew not found; skipped"
    return 0
  fi

  local casks=(font-lilex-nerd-font)

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: brew uninstall --cask ${casks[*]}"
    log_success "Dry run"
    return 0
  fi

  start_spinner "Removing casks"
  local removed=0
  for c in "${casks[@]}"; do
    if brew list --cask "$c" >/dev/null 2>&1; then
      if brew uninstall --cask "$c" >/dev/null 2>&1; then
        ((removed += 1))
      fi
    fi
  done
  stop_spinner

  ((CASKS_REMOVED += removed))
  if ((removed == 0)); then
    log_success "Nothing to remove"
  else
    log_success "Removed $removed"
  fi
}

cleanup_homebrew() {
  log_step "Cleaning up Homebrew"

  if [[ "$RUN_BREW_CLEANUP" != "1" ]]; then
    log_success "Skipped"
    return 0
  fi

  if ! command -v brew >/dev/null 2>&1; then
    log_success "Homebrew not found; skipped"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: brew autoremove -q"
    log_muted "DRY-RUN: brew cleanup -q"
    log_success "Dry run"
    return 0
  fi

  start_spinner "brew autoremove && brew cleanup"
  brew autoremove -q >/dev/null 2>&1 || true
  brew cleanup -q >/dev/null 2>&1 || true
  stop_spinner

  log_success "Complete"
}

remove_local_repos() {
  log_step "Removing local repositories"

  if [[ "$REMOVE_DOTFILES_REPO" == "1" ]]; then
    if [[ -d "$DOTFILES_DIRECTORY" ]]; then
      run_cmd rm -rf "$DOTFILES_DIRECTORY" >/dev/null 2>&1 || true
      log_success "Removed dotfiles repo"
    else
      log_success "Dotfiles repo not found"
    fi
  else
    log_success "Dotfiles repo kept"
  fi

  if [[ "$REMOVE_WORKSTATION_REPO" == "1" ]]; then
    if [[ -d "$WORKSTATION_DIRECTORY" ]]; then
      run_cmd rm -rf "$WORKSTATION_DIRECTORY" >/dev/null 2>&1 || true
      log_success "Removed workstation repo"
    else
      log_success "Workstation repo not found"
    fi
  else
    log_success "Workstation repo kept"
  fi
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "macOS Development Environment Rollback"
  printf "\n"

  require_macos
  confirm_rollback_operation

  remove_dotfiles_symlinks
  uninstall_homebrew_formulae
  uninstall_nerd_fonts
  cleanup_homebrew
  remove_local_repos

  printf "\n"
  print_summary
  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

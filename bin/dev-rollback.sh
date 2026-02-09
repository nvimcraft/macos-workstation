#!/usr/bin/env bash

# nvimcraft macOS development environment rollback

set -euo pipefail

readonly BOLD=$'\033[1m'
readonly DIM=$'\033[2m'
readonly GREEN=$'\033[32m'
readonly BLUE=$'\033[34m'
readonly YELLOW=$'\033[33m'
readonly RED=$'\033[31m'
readonly NC=$'\033[0m'

readonly DOTFILES_DIRECTORY="$HOME/dotfiles-macos"

SPINNER_PID=""
PACKAGES_REMOVED=0
SYMLINKS_REMOVED=0

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

log_removed() {
  printf "${RED}✗${NC} %s\n" "$1"
}

log_warning() {
  printf "${YELLOW}⚠${NC} %s\n" "$1"
}

log_muted() {
  printf "${DIM}%s${NC}\n" "$1"
}

print_summary() {
  log_header "Rollback Summary"
  printf "  ${DIM}Packages removed:${NC} %d  ${DIM}Symlinks removed:${NC} %d\n" \
    "$PACKAGES_REMOVED" "$SYMLINKS_REMOVED"
}

handle_exit() {
  stop_spinner
  printf "\n"
}

trap handle_exit EXIT INT TERM

confirm_rollback_operation() {
  clear
  log_header "macOS Development Environment Rollback"
  printf "\n"

  log_warning "This will remove dotfiles-macos configuration and related tooling"
  printf "\n%sThe following will be removed:%s\n" "$DIM" "$NC"
  printf "  %s•%s dotfiles-macos repository at %s\n" "$DIM" "$NC" "$DOTFILES_DIRECTORY"
  printf "  %s•%s Symbolic links created by stow for dotfiles-macos\n" "$DIM" "$NC"
  printf "  %s•%s Homebrew packages installed by bootstrap.sh\n" "$DIM" "$NC"
  printf "  %s•%s Nerd Fonts installed via Homebrew\n" "$DIM" "$NC"
  printf "\n"

  read -rp "$(printf "%sAre you sure you want to proceed? (y/N):%s " "$YELLOW" "$NC")" user_confirmation

  if [[ "$user_confirmation" != "y" && "$user_confirmation" != "Y" ]]; then
    printf "\n%s→%s %sRollback operation cancelled by user%s\n" \
      "$BLUE" "$NC" "$DIM" "$NC"
    exit 0
  fi

  printf "\n"
}

remove_dotfiles_macos_symlinks() {
  if [[ ! -d "$DOTFILES_DIRECTORY" ]]; then
    log_skip "dotfiles-macos directory not found"
    return
  fi

  log_step "Removing dotfiles-macos symbolic links"
  start_spinner "Unlinking dotfiles-macos configuration files"

  pushd "$DOTFILES_DIRECTORY" >/dev/null 2>&1 || {
    stop_spinner
    log_skip "Could not access dotfiles-macos directory"
    popd >/dev/null 2>&1 || true
    return
  }

  if stow -D . >/dev/null 2>&1; then
    SYMLINKS_REMOVED=1
    stop_spinner
    log_removed "Successfully removed dotfiles-macos symbolic links"
  else
    stop_spinner
    log_skip "No dotfiles-macos symbolic links to remove"
  fi

  popd >/dev/null 2>&1
}

uninstall_homebrew_packages() {
  if ! command -v brew >/dev/null 2>&1; then
    log_skip "Homebrew not found on system"
    return
  fi

  local homebrew_package_names=(
    stow node git gh neovim tmux
    go python
    ripgrep bat eza tree tlrc zoxide delta
    powerlevel10k zsh-autosuggestions zsh-syntax-highlighting
  )

  log_step "Uninstalling Homebrew command line packages"
  start_spinner "Removing CLI tools and development utilities"

  local packages_removed=0
  for package_name in "${homebrew_package_names[@]}"; do
    if brew uninstall --ignore-dependencies "$package_name" >/dev/null 2>&1; then
      ((packages_removed++))
    fi
  done

  stop_spinner
  if [[ $packages_removed -eq 0 ]]; then
    log_skip "No Homebrew packages to remove"
  else
    log_removed "Successfully removed $packages_removed Homebrew packages"
    ((PACKAGES_REMOVED += packages_removed))
  fi
}

uninstall_nerd_fonts() {
  if ! command -v brew >/dev/null 2>&1; then
    return
  fi

  local nerd_font_names=(
    font-lilex-nerd-font
  )

  log_step "Uninstalling Nerd Fonts for terminal"
  start_spinner "Removing programming fonts with icon support"

  local fonts_removed=0
  for font_name in "${nerd_font_names[@]}"; do
    if brew uninstall --cask "$font_name" >/dev/null 2>&1; then
      ((fonts_removed++))
    fi
  done

  stop_spinner
  if [[ $fonts_removed -eq 0 ]]; then
    log_skip "No Nerd Fonts to remove"
  else
    log_removed "Successfully removed $fonts_removed Nerd Fonts"
    ((PACKAGES_REMOVED += fonts_removed))
  fi
}

remove_dotfiles_macos_repository() {
  if [[ ! -d "$DOTFILES_DIRECTORY" ]]; then
    log_skip "dotfiles-macos repository not found"
    return
  fi

  log_step "Removing dotfiles-macos repository from GitHub"
  start_spinner "Deleting dotfiles-macos directory at $DOTFILES_DIRECTORY"

  if rm -rf "$DOTFILES_DIRECTORY" 2>/dev/null; then
    stop_spinner
    log_removed "Successfully removed dotfiles-macos repository"
  else
    stop_spinner
    log_skip "Could not remove dotfiles-macos repository"
  fi
}

cleanup_homebrew_dependencies() {
  if ! command -v brew >/dev/null 2>&1; then
    return
  fi

  log_step "Cleaning up Homebrew package manager"
  start_spinner "Removing unused dependencies and clearing cache"

  brew autoremove -q >/dev/null 2>&1 || true
  brew cleanup -q >/dev/null 2>&1 || true

  stop_spinner
  log_success "Successfully cleaned up Homebrew package manager"
}

main() {
  confirm_rollback_operation

  remove_dotfiles_macos_symlinks
  uninstall_homebrew_packages
  uninstall_nerd_fonts
  remove_dotfiles_macos_repository
  cleanup_homebrew_dependencies

  printf "\n"
  print_summary
  printf "\n%s✓%s %smacOS development environment rollback complete%s\n" \
    "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

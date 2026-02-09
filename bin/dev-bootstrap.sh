#!/usr/bin/env bash

# nvimcraft macOS development environment bootstrap

# Exit on error, unset variables, or failed pipelines.
set -euo pipefail

# Output formatting
readonly BOLD=$'\033[1m'
readonly DIM='$\033[2m'
readonly GREEN=$'\033[32m'
readonly BLUE=$'\033[34m'
readonly YELLOW=$'\033[33m'
readonly NC=$'\033[0m'

# Target directory for dotfiles repository
readonly DOTFILES_DIRECTORY="$HOME/dotfiles-macos"

# Override via DOTFILES_REPO if needed
readonly DOTFILES_REPOSITORY_URL="${DOTFILES_REPO:-https://github.com/nvimcraft/dotfiles-macos.git}"

# Status output and progress indication

# PID of the active spinner process (if any)
SPINNER_PID=""

# Start a non-blocking spinner with a status message.
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

# Stop the active spinner and clean up terminal state.
stop_spinner() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null &&
      wait "$SPINNER_PID" 2>/dev/null ||
      true
    SPINNER_PID=""
  fi

  # Clear spinner line
  printf "\r\033[K"
}

# Structured logging helpers
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

# Ensure spinner cleanup on exit or interruption.
handle_exit() {
  stop_spinner
  printf "\n"
}

trap handle_exit EXIT INT TERM

# System prerequisites

# Ensure Xcode Command Line Tools are installed.
install_xcode_command_line_tools() {
  log_step "Ensuring Xcode command line tools are installed"

  # Fast path, tools already present
  if xcode-select -p &>/dev/null; then
    log_skip "Xcode command line tools already installed"
    return
  fi

  # Trigger installation prompt (macOS-managed)
  start_spinner "Installing Xcode CLI tools (this may take several minutes)"
  xcode-select --install 2>/dev/null || true

  # Block until installation completes.
  # There is no reliable event hook, so we poll for availability.
  while ! xcode-select -p &>/dev/null; do
    sleep 10
  done

  stop_spinner
  log_success "Xcode command line tools installed"
}

# Install and configure Homebrew.
# Handles both Apple Silicon and Intel macOS layouts.
install_homebrew_package_manager() {
  local system_architecture
  local homebrew_prefix

  system_architecture="$(uname -m)"
  homebrew_prefix="/opt/homebrew"

  # Intel Macs use a legacy Homebrew prefix
  if [[ "$system_architecture" != "arm64" ]]; then
    homebrew_prefix="/usr/local"
  fi

  log_step "Ensuring Homebrew package manager is installed"

  if command -v brew &>/dev/null; then
    log_skip "Homebrew package manager already installed"
    return
  fi

  start_spinner "Downloading and installing Homebrew"

  # Use the official Homebrew installer
  if /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    stop_spinner

    # Validate installation explicitly
    if command -v brew &>/dev/null; then
      log_success "Homebrew package manager installed"
    else
      log_muted "Homebrew installation completed, but 'brew' command was not found"
      exit 1
    fi
  else
    stop_spinner
    log_muted "Failed to install Homebrew package manager"
    exit 1
  fi

  # Homebrew shell integration
  log_step "Configuring Homebrew shell environment"

  if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    echo "eval \"\$($homebrew_prefix/bin/brew shellenv)\"" >>"$HOME/.zprofile"
    log_success "Added Homebrew shell initialization to ~/.zprofile"
  else
    log_skip "Homebrew shell environment already configured"
  fi

  # Load Homebrew into the current process.
  # This avoids requiring a terminal restart during setup.
  eval "$($homebrew_prefix/bin/brew shellenv)"
  export PATH

  # Disable Homebrew analytics
  log_step "Disabling Homebrew analytics"
  brew analytics off >/dev/null 2>&1
  log_success "Homebrew analytics disabled"
}

# Install baseline CLI tools used across this development environment.
install_command_line_packages() {
  local cli_package_names=(
    stow node git gh neovim tmux
    go python
    ripgrep bat eza tree tlrc zoxide delta
    powerlevel10k zsh-autosuggestions zsh-syntax-highlighting
  )

  log_step "Installing command line packages via Homebrew"
  start_spinner "Installing CLI tools and development utilities"

  local packages_installed=0

  for package_name in "${cli_package_names[@]}"; do
    # Skip already-installed packages
    if ! brew list "$package_name" >/dev/null 2>&1; then
      brew install "$package_name" >/dev/null 2>&1
      ((packages_installed++))
    fi
  done

  stop_spinner

  if [[ $packages_installed -eq 0 ]]; then
    log_skip "All command line packages already installed"
  else
    log_success "Installed $packages_installed command line packages"
  fi
}

# Install Nerd Fonts
install_nerd_fonts() {
  local nerd_font_names=(
    font-lilex-nerd-font
  )

  log_step "Installing Nerd Fonts for terminal"
  start_spinner "Installing programming fonts with icon support"

  local fonts_installed=0

  for font_name in "${nerd_font_names[@]}"; do
    # Fonts are installed as Homebrew casks
    if ! brew list --cask "$font_name" >/dev/null 2>&1; then
      brew install --cask "$font_name" >/dev/null 2>&1
      ((fonts_installed++))
    fi
  done

  stop_spinner

  if [[ $fonts_installed -eq 0 ]]; then
    log_skip "All Nerd Fonts already installed"
  else
    log_success "Installed $fonts_installed Nerd Fonts"
  fi
}

# Dotfiles repository management
clone_dotfiles_repository() {
  # Skip cloning if already inside the correct dotfiles repository
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local current_remote
    current_remote="$(git remote get-url origin 2>/dev/null || echo "")"

    if [[ "$current_remote" == *"$DOTFILES_REPOSITORY_URL"* ]] ||
      [[ "$current_remote" == *"$DOTFILES_REPO"* ]]; then
      log_skip "Already in the correct dotfiles-macos repository"
      return
    fi
  fi

  # Skip cloning if target directory exists and points to the correct repo
  if [[ -d "$DOTFILES_DIRECTORY" ]] && [[ -d "$DOTFILES_DIRECTORY/.git" ]]; then
    pushd "$DOTFILES_DIRECTORY" >/dev/null

    local existing_remote
    existing_remote="$(git remote get-url origin 2>/dev/null || echo "")"

    popd >/dev/null

    if [[ "$existing_remote" == *"$DOTFILES_REPOSITORY_URL"* ]] ||
      [[ "$existing_remote" == *"$DOTFILES_REPO"* ]]; then
      log_skip "dotfiles-macos repository directory already exists and is correct"
      return
    else
      log_muted "Warning: $DOTFILES_DIRECTORY exists but is not the expected repository"
      log_muted "Skipping clone to avoid overwriting local data"
      return
    fi
  fi

  # Repository does not exist locally — clone it.
  log_step "Cloning dotfiles-macos repository from GitHub"
  start_spinner "Downloading configuration files from $DOTFILES_REPOSITORY_URL"

  if git clone "$DOTFILES_REPOSITORY_URL" "$DOTFILES_DIRECTORY" >/dev/null 2>&1; then
    stop_spinner
    log_success "Successfully cloned dotfiles-macos repository"
  else
    stop_spinner
    log_muted "Error: Failed to clone dotfiles-macos repository"
    exit 1
  fi
}

# Dotfiles linking using GNU Stow
link_dotfiles_with_stow() {
  if [[ ! -d "$DOTFILES_DIRECTORY" ]]; then
    log_muted "Error: dotfiles-macos directory not found at $DOTFILES_DIRECTORY"
    exit 1
  fi

  log_step "Linking dotfiles-macos configuration files"
  start_spinner "Creating symbolic links for configuration files"

  pushd "$DOTFILES_DIRECTORY" >/dev/null
  stow . >/dev/null 2>&1
  popd >/dev/null

  stop_spinner
  log_success "Successfully linked dotfiles-macos configuration files"

  # Refresh bat cache if present
  if command -v bat &>/dev/null; then
    start_spinner "Rebuilding bat syntax highlighting cache"
    bat cache --build >/dev/null 2>&1
    stop_spinner
    log_success "Successfully rebuilt bat cache"
  fi
}

# Script permissions
make_scripts_executable() {
  local scripts_directory="$DOTFILES_DIRECTORY/scripts"

  if [[ ! -d "$scripts_directory" ]]; then
    log_skip "dotfiles-macos scripts directory not found"
    return
  fi

  log_step "Making dotfiles-macos scripts executable"
  start_spinner "Setting execute permissions on shell scripts"

  chmod +x "$scripts_directory"/*.sh 2>/dev/null

  stop_spinner
  log_success "Successfully made dotfiles-macos scripts executable"
}

# Editor environment
prepare_neovim_environment() {
  log_step "Preparing Neovim development environment"
  log_success "Neovim environment ready (launch nvim to install plugins)"
}

# Entry point
main() {
  clear 2>/dev/null || true
  log_header "macOS Development Environment Setup"
  printf "\n"

  install_xcode_command_line_tools
  install_homebrew_package_manager
  install_command_line_packages
  install_nerd_fonts
  clone_dotfiles_repository
  link_dotfiles_with_stow
  make_scripts_executable
  prepare_neovim_environment

  printf "\n"
  log_header "macOS Development Environment Setup Complete"
  printf "\n%s✓%s %sDevelopment environment ready for use%s\n" \
    "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

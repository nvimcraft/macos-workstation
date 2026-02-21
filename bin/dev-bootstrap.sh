#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

NO_SPINNER=0
NO_CLEAR=0
DRY_RUN=0
DEBUG_FLAG=0

DOTFILES_DIRECTORY="${DOTFILES_DIRECTORY:-$HOME/dotfiles-macos}"
DOTFILES_REPOSITORY_URL="${DOTFILES_REPO:-https://github.com/nvimcraft/dotfiles-macos.git}"

WORKSTATION_DIRECTORY="${WORKSTATION_DIRECTORY:-$HOME/Developer/projects/github/macos-workstation}"
WORKSTATION_REPOSITORY_URL="${WORKSTATION_REPO:-https://github.com/nvimcraft/macos-workstation.git}"

for arg in "$@"; do
  case "$arg" in
  --no-spinner) NO_SPINNER=1 ;;
  --no-clear) NO_CLEAR=1 ;;
  --dry-run) DRY_RUN=1 ;;
  --debug) DEBUG_FLAG=1 ;;
  -h | --help)
    cat <<'EOF'
Usage: dev-bootstrap.sh [options]
  --dry-run      Show what would be done, but do not make changes
  --no-spinner   Disable spinner
  --no-clear     Don't clear screen
  --debug        Enable shell tracing (set -x)
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

readonly DOTFILES_DIRECTORY DOTFILES_REPOSITORY_URL
readonly WORKSTATION_DIRECTORY WORKSTATION_REPOSITORY_URL
readonly DRY_RUN

SPINNER_PID=""

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

# Avoid double-firing
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
    log_muted "Error: This bootstrap script is intended for macOS (Darwin) only"
    exit 1
  fi
  log_success "Ready"
}

validate_prerequisites() {
  log_step "Checking prerequisites"

  if [[ ! -w "$HOME" ]]; then
    log_muted "Error: Home directory is not writable: $HOME"
    exit 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    log_muted "Error: curl is required but not found"
    exit 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    log_muted "Note: git not found yet (will be available after Xcode CLT install)"
  fi

  log_success "Ready"
}

install_xcode_command_line_tools() {
  log_step "Ensuring Xcode command line tools are installed"

  if xcode-select -p >/dev/null 2>&1; then
    log_success "Already installed"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_success "Dry run"
    return 0
  fi

  start_spinner "Triggering Xcode CLI tools installer prompt"
  xcode-select --install >/dev/null 2>&1 || true
  stop_spinner

  start_spinner "Waiting for Xcode CLI tools to become available"
  local attempts=0
  until xcode-select -p >/dev/null 2>&1; do
    ((attempts += 1))
    if ((attempts > 120)); then
      stop_spinner
      log_muted "Error: Xcode CLI tools not detected after waiting. Install manually then re-run."
      exit 1
    fi
    sleep 5
  done
  stop_spinner

  log_success "Installed"
}

detect_homebrew_prefix() {
  if command -v brew >/dev/null 2>&1; then
    brew --prefix
    return 0
  fi

  if [[ "$(uname -m)" == "arm64" ]]; then
    printf "%s" "/opt/homebrew"
  else
    printf "%s" "/usr/local"
  fi
}

install_homebrew() {
  log_step "Ensuring Homebrew is installed"

  if command -v brew >/dev/null 2>&1; then
    log_success "Already installed"
  else
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_muted "DRY-RUN: NONINTERACTIVE=1 /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
      log_success "Dry run"
      return 0
    fi

    log_step "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    log_success "Installer completed"
  fi

  local homebrew_prefix=""
  homebrew_prefix="$(detect_homebrew_prefix)"

  log_step "Configuring Homebrew shell environment"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: eval \"\$(${homebrew_prefix}/bin/brew shellenv)\""
    log_muted "DRY-RUN: append brew shellenv to ~/.zprofile if missing"
    log_muted "DRY-RUN: brew analytics off"
    log_success "Dry run"
    return 0
  fi

  if [[ -x "${homebrew_prefix}/bin/brew" ]]; then
    eval "$("${homebrew_prefix}/bin/brew" shellenv)"
  else
    eval "$(brew shellenv)"
  fi

  if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
    echo "eval \"\$(${homebrew_prefix}/bin/brew shellenv)\"" >>"$HOME/.zprofile"
    log_success "Added to ~/.zprofile"
  else
    log_success "Already configured in ~/.zprofile"
  fi

  log_step "Disabling Homebrew analytics"
  brew analytics off >/dev/null 2>&1 || true
  log_success "Disabled"
}

install_cli_packages() {
  local cli_packages=(
    stow node git gh neovim tmux
    go python
    ripgrep bat eza tree tlrc zoxide delta
    powerlevel10k zsh-autosuggestions zsh-syntax-highlighting
  )

  log_step "Installing command line packages"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: brew install ${cli_packages[*]}"
    log_success "Dry run"
    return 0
  fi

  start_spinner "Resolving missing CLI tools"
  local missing=()
  for p in "${cli_packages[@]}"; do
    if ! brew list "$p" >/dev/null 2>&1; then
      missing+=("$p")
    fi
  done
  stop_spinner

  if ((${#missing[@]} > 0)); then
    start_spinner "Installing ${#missing[@]} CLI tool(s)"
    brew install "${missing[@]}" >/dev/null 2>&1
    stop_spinner
    log_success "Installed ${#missing[@]} package(s)"
  else
    log_success "Already installed"
  fi
}

install_nerd_fonts() {
  local nerd_fonts=(font-lilex-nerd-font)

  log_step "Installing Nerd Fonts"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: brew tap homebrew/cask-fonts"
    log_muted "DRY-RUN: brew install --cask ${nerd_fonts[*]}"
    log_success "Dry run"
    return 0
  fi

  brew tap homebrew/cask-fonts >/dev/null 2>&1 || true

  start_spinner "Resolving missing Nerd Fonts"
  local missing=()
  for f in "${nerd_fonts[@]}"; do
    if ! brew list --cask "$f" >/dev/null 2>&1; then
      missing+=("$f")
    fi
  done
  stop_spinner

  if ((${#missing[@]} > 0)); then
    start_spinner "Installing ${#missing[@]} Nerd Font(s)"
    brew install --cask "${missing[@]}" >/dev/null 2>&1
    stop_spinner
    log_success "Installed ${#missing[@]} Nerd Font(s)"
  else
    log_success "Already installed"
  fi
}

clone_or_update_repo() {
  local repo_url="$1"
  local target_dir="$2"
  local label="$3"

  if [[ -d "${target_dir}/.git" ]]; then
    log_step "Updating $label"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_muted "DRY-RUN: git -C \"$target_dir\" pull --ff-only"
      log_success "Dry run"
      return 0
    fi
    start_spinner "Pulling latest changes"
    git -C "$target_dir" pull --ff-only >/dev/null 2>&1 || true
    stop_spinner
    log_success "Updated"
    return 0
  fi

  if [[ -d "$target_dir" ]]; then
    log_muted "Warning: $target_dir exists but is not a git repo; skipping clone to avoid overwriting."
    return 0
  fi

  log_step "Cloning $label"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: git clone \"$repo_url\" \"$target_dir\""
    log_success "Dry run"
    return 0
  fi

  start_spinner "Cloning from remote"
  git clone "$repo_url" "$target_dir" >/dev/null 2>&1
  stop_spinner
  log_success "Cloned"
}

sync_workstation_scripts_into_dotfiles() {
  log_step "Syncing workstation scripts into dotfiles"

  clone_or_update_repo "$WORKSTATION_REPOSITORY_URL" "$WORKSTATION_DIRECTORY" "macos-workstation"

  local dest="${DOTFILES_DIRECTORY}/scripts"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: mkdir -p \"$dest\""
    log_muted "DRY-RUN: rsync -a --delete \"${WORKSTATION_DIRECTORY}/\" \"${dest}/\""
    log_success "Dry run"
    return 0
  fi

  mkdir -p "$dest"

  start_spinner "Copying scripts into ${dest}"
  rsync -a --delete "${WORKSTATION_DIRECTORY}/" "${dest}/" >/dev/null 2>&1 || true
  stop_spinner

  log_success "Synced"
}

ensure_stow_local_ignore() {
  local ignore_file="${DOTFILES_DIRECTORY}/.stow-local-ignore"

  if [[ -f "$ignore_file" ]]; then
    log_success "Already configured"
    return 0
  fi

  log_step "Creating .stow-local-ignore"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: write $ignore_file"
    log_success "Dry run"
    return 0
  fi

  cat >"$ignore_file" <<'EOF'
# Stow ignore patterns (includes common defaults + local-only folders)

# Common defaults
RCS
.+,v
CVS
.#.+
.cvsignore
.svn
_darcs
.hg
.git
.gitignore
.gitmodules
.+~
#.*#
^/README.*
^/LICENSE.*
^/COPYING

# Local-only / do-not-stow folders for this repo layout
^/scripts
^/\.jj
EOF

  log_success "Created"
}

link_dotfiles_with_stow() {
  log_step "Linking dotfiles with Stow"

  if [[ ! -d "$DOTFILES_DIRECTORY" ]]; then
    log_muted "Error: dotfiles directory not found at $DOTFILES_DIRECTORY"
    exit 1
  fi

  if ! command -v stow >/dev/null 2>&1; then
    log_muted "Error: stow is required but not found"
    exit 1
  fi

  ensure_stow_local_ignore

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: (cd \"$DOTFILES_DIRECTORY\" && stow --target \"$HOME\" -n .)"
    log_muted "DRY-RUN: (cd \"$DOTFILES_DIRECTORY\" && stow --target \"$HOME\" .)"
    log_success "Dry run"
    return 0
  fi

  start_spinner "Checking for stow conflicts"
  pushd "$DOTFILES_DIRECTORY" >/dev/null 2>&1 || exit 1

  if ! stow --target "$HOME" -n . >/dev/null 2>&1; then
    stop_spinner
    popd >/dev/null 2>&1 || true
    log_muted "Error: Stow conflict detected"
    log_muted "Run: (cd \"$DOTFILES_DIRECTORY\" && stow --target \"$HOME\" -n .) to see details."
    exit 1
  fi

  stop_spinner
  start_spinner "Creating symlinks in \$HOME"

  if ! stow --target "$HOME" . >/dev/null 2>&1; then
    stop_spinner
    popd >/dev/null 2>&1 || true
    log_muted "Error: Stow failed while creating symlinks"
    exit 1
  fi

  popd >/dev/null 2>&1 || exit 1
  stop_spinner

  log_success "Linked"

  if command -v bat >/dev/null 2>&1; then
    start_spinner "Rebuilding bat cache"
    bat cache --build >/dev/null 2>&1 || true
    stop_spinner
    log_success "Rebuilt bat cache"
  fi
}

make_scripts_executable() {
  local scripts_dir="${DOTFILES_DIRECTORY}/scripts"

  log_step "Making scripts executable"

  if [[ ! -d "$scripts_dir" ]]; then
    log_success "No scripts directory"
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: chmod +x \"${scripts_dir}\"/*.sh"
    log_success "Dry run"
    return 0
  fi

  start_spinner "Setting execute permissions on *.sh"
  chmod +x "${scripts_dir}"/*.sh >/dev/null 2>&1 || true
  stop_spinner
  log_success "Done"
}

prepare_neovim_environment() {
  log_step "Preparing Neovim environment"
  log_success "Ready"
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "macOS Development Environment Setup"
  printf "\n"

  require_macos
  validate_prerequisites

  printf "\n"

  install_xcode_command_line_tools
  install_homebrew
  install_cli_packages
  install_nerd_fonts

  clone_or_update_repo "$DOTFILES_REPOSITORY_URL" "$DOTFILES_DIRECTORY" "dotfiles-macos"
  sync_workstation_scripts_into_dotfiles

  link_dotfiles_with_stow
  make_scripts_executable
  prepare_neovim_environment

  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

DRY_RUN=0
KEEP_HISTORY=0
NO_SPINNER=0
NO_CLEAR=0

for arg in "$@"; do
  case "$arg" in
  --dry-run) DRY_RUN=1 ;;
  --keep-history) KEEP_HISTORY=1 ;;
  --no-spinner) NO_SPINNER=1 ;;
  --no-clear) NO_CLEAR=1 ;;
  -h | --help)
    cat <<'EOF'
Usage: system-cleanup.sh [options]
  --dry-run        Show what would be removed, but do not delete anything
  --keep-history   Do not remove shell history files (~/.zsh_history, ~/.bash_history, etc.)
  --no-spinner     Disable spinner
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
  NO_SPINNER=1
fi
readonly BOLD DIM GREEN BLUE NC

SPINNER_PID=""
ITEMS_CLEANED=0
ITEMS_SKIPPED=0

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

print_summary() {
  log_header "Summary"
  printf "  ${DIM}Cleaned:${NC} %d  ${DIM}Skipped:${NC} %d\n" \
    "$ITEMS_CLEANED" "$ITEMS_SKIPPED"
}

handle_exit() {
  stop_spinner
  printf "\n"
}

# Avoid double-firing
trap handle_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

verify_environment_ready() {
  log_step "Checking environment"
  # Basic sanity: HOME should exist and be a directory
  if [[ -z "${HOME:-}" || ! -d "$HOME" ]]; then
    log_muted "Error: HOME not set or not a directory"
    exit 1
  fi
  log_success "Ready"
}

remove_path() {
  local target_path="$1"

  if [[ ! -e "$target_path" ]]; then
    ((ITEMS_SKIPPED += 1))
    return 0
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_muted "DRY-RUN: would remove $target_path"
    ((ITEMS_CLEANED += 1))
    return 0
  fi

  if rm -rf -- "$target_path" 2>/dev/null; then
    ((ITEMS_CLEANED += 1))
  else
    ((ITEMS_SKIPPED += 1))
  fi
}

remove_shell_history_files() {
  local shell_history_files=(
    "$HOME/.zsh_history"
    "$HOME/.bash_history"
    "$HOME/.python_history"
    "$HOME/.mysql_history"
    "$HOME/.psql_history"
    "$HOME/.lesshst"
  )

  for history_file_path in "${shell_history_files[@]}"; do
    remove_path "$history_file_path"
  done
}

remove_editor_temporary_files() {
  local editor_temp_paths=(
    "$HOME/.viminfo"
    "$HOME/.vim/swap"
    "$HOME/.vim/backup"
    "$HOME/.biome"
  )

  for editor_temp_path in "${editor_temp_paths[@]}"; do
    remove_path "$editor_temp_path"
  done
}

remove_package_manager_caches() {
  local package_cache_directories=(
    "$HOME/.npm"
    "$HOME/.pnpm"
    "$HOME/.yarn"
    "$HOME/.bun"
  )

  for cache_directory_path in "${package_cache_directories[@]}"; do
    remove_path "$cache_directory_path"
  done
}

remove_homebrew_cache_and_logs() {
  local homebrew_cache_paths=(
    "$HOME/Library/Caches/Homebrew"
    "$HOME/Library/Logs/Homebrew"
  )

  for homebrew_cache_path in "${homebrew_cache_paths[@]}"; do
    remove_path "$homebrew_cache_path"
  done
}

remove_system_cache_and_metadata() {
  local system_cache_paths=(
    "$HOME/.cache"
    "$HOME/.DS_Store"
    "$HOME/.zcompdump"
  )

  for system_cache_path in "${system_cache_paths[@]}"; do
    remove_path "$system_cache_path"
  done
}

cleanup_environment() {
  log_step "Cleaning up"
  start_spinner "Removing cache and temporary files"

  if [[ "$KEEP_HISTORY" -eq 0 ]]; then
    remove_shell_history_files
  else
    log_muted "Skipping shell history files"
  fi

  remove_editor_temporary_files
  remove_package_manager_caches
  remove_homebrew_cache_and_logs
  remove_system_cache_and_metadata

  stop_spinner

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_success "Dry run"
  else
    log_success "Clean"
  fi
}

main() {
  if [[ "$NO_CLEAR" -eq 0 && -t 1 ]]; then clear || true; fi

  log_header "System Cleanup"
  printf "\n"

  verify_environment_ready
  cleanup_environment

  printf "\n"
  print_summary
  printf "\n%s✓%s %sComplete%s\n" "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

#!/usr/bin/env bash

# nvimcraft macOS system cleanup script

set -euo pipefail

readonly BOLD=$'\033[1m'
readonly DIM=$'\033[2m'
readonly GREEN=$'\033[32m'
readonly BLUE=$'\033[34m'
readonly NC=$'\033[0m'

SPINNER_PID=""
ITEMS_CLEANED=0
ITEMS_SKIPPED=0

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

log_muted() {
  printf "${DIM}%s${NC}\n" "$1"
}

print_summary() {
  log_header "Summary"
  printf "  ${DIM}Cleaned:${NC} %d  ${DIM}Skipped:${NC} %d\n" \
    "$ITEMS_CLEANED" "$ITEMS_SKIPPED"
}

handle_exit() {
  stop_spinner
  printf "\n"
}

trap handle_exit EXIT INT TERM

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
    if [[ -e "$history_file_path" ]]; then
      if rm -rf "$history_file_path" 2>/dev/null; then
        ((ITEMS_CLEANED += 1))
      else
        ((ITEMS_SKIPPED += 1))
      fi
    else
      ((ITEMS_SKIPPED += 1))
    fi
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
    if [[ -e "$editor_temp_path" ]]; then
      if rm -rf "$editor_temp_path" 2>/dev/null; then
        ((ITEMS_CLEANED += 1))
      else
        ((ITEMS_SKIPPED += 1))
      fi
    else
      ((ITEMS_SKIPPED += 1))
    fi
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
    if [[ -e "$cache_directory_path" ]]; then
      if rm -rf "$cache_directory_path" 2>/dev/null; then
        ((ITEMS_CLEANED += 1))
      else
        ((ITEMS_SKIPPED += 1))
      fi
    else
      ((ITEMS_SKIPPED += 1))
    fi
  done
}

remove_homebrew_cache_and_logs() {
  local homebrew_cache_paths=(
    "$HOME/Library/Caches/Homebrew"
    "$HOME/Library/Logs/Homebrew"
  )

  for homebrew_cache_path in "${homebrew_cache_paths[@]}"; do
    if [[ -e "$homebrew_cache_path" ]]; then
      if rm -rf "$homebrew_cache_path" 2>/dev/null; then
        ((ITEMS_CLEANED += 1))
      else
        ((ITEMS_SKIPPED += 1))
      fi
    else
      ((ITEMS_SKIPPED += 1))
    fi
  done
}

remove_system_cache_and_metadata() {
  local system_cache_paths=(
    "$HOME/.cache"
    "$HOME/.DS_Store"
    "$HOME/.zcompdump"
  )

  for system_cache_path in "${system_cache_paths[@]}"; do
    if [[ -e "$system_cache_path" ]]; then
      if rm -rf "$system_cache_path" 2>/dev/null; then
        ((ITEMS_CLEANED += 1))
      else
        ((ITEMS_SKIPPED += 1))
      fi
    else
      ((ITEMS_SKIPPED += 1))
    fi
  done
}

execute_system_cleanup() {
  log_step "Removing cache and temporary files"
  start_spinner "Cleaning shell history, editor files, and package caches"

  remove_shell_history_files
  remove_editor_temporary_files
  remove_package_manager_caches
  remove_homebrew_cache_and_logs
  remove_system_cache_and_metadata

  stop_spinner

  if [[ "$ITEMS_CLEANED" -eq 0 ]]; then
    log_success "System already clean"
  else
    log_success "Removed $ITEMS_CLEANED items"
  fi
}

main() {
  clear
  log_header "System Cleanup"
  printf "\n"

  execute_system_cleanup

  printf "\n"
  print_summary
  printf "\n%s✓%s %sComplete%s\n" \
    "$GREEN" "$NC" "$DIM" "$NC"
}

main "$@"

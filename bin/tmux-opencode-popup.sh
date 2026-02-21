#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'

POPUP_W="80%"
POPUP_H="80%"
CMD="opencode"

for arg in "$@"; do
  case "$arg" in
  --width=*) POPUP_W="${arg#--width=}" ;;
  --height=*) POPUP_H="${arg#--height=}" ;;
  --cmd=*) CMD="${arg#--cmd=}" ;;
  -h | --help)
    cat <<'EOF'
Usage: tmux-opencode-popup.sh [options]
  --width=SIZE    Popup width  (default: 80%)
  --height=SIZE   Popup height (default: 80%)
  --cmd=COMMAND   Command to run in the session (default: opencode)
EOF
    exit 0
    ;;
  esac
done

# Get current pane path; if not in tmux, exit quietly.
pane_path="$(tmux display-message -p -F '#{pane_current_path}' 2>/dev/null)" || exit 0

# Compute an 8-char hash of the path (quietly).
if command -v md5sum >/dev/null 2>&1; then
  hash="$(printf '%s' "$pane_path" | md5sum 2>/dev/null | cut -d' ' -f1 | cut -c1-8)"
else
  hash="$(printf '%s' "$pane_path" | md5 -q 2>/dev/null | cut -c1-8)"
fi

session="opencode-$hash"

# Ensure session exists (no output on the original pane).
if ! tmux has-session -t "$session" 2>/dev/null; then
  tmux new-session -d -s "$session" -c "$pane_path" "$CMD" >/dev/null 2>&1 || exit 0
fi

# Popup attach; suppress any possible error blip.
tmux display-popup -w "$POPUP_W" -h "$POPUP_H" -E "tmux attach-session -t \"$session\"" 2>/dev/null || exit 0

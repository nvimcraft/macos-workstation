#!/usr/bin/env bash

set -euo pipefail

pane_path="$(tmux display-message -p -F '#{pane_current_path}')" || exit 0

# path hash (md5sum if present)
if command -v md5sum >/dev/null 2>&1; then
  hash="$(printf %s "$pane_path" | md5sum | awk '{print $1}' | cut -c1-8)"
else
  hash="$(printf %s "$pane_path" | md5 -q | cut -c1-8)"
fi

session="opencode-$hash"

# ensure session
tmux has-session -t "$session" 2>/dev/null ||
  tmux new-session -d -s "$session" -c "$pane_path" opencode ||
  exit 0

# popup attach
tmux display-popup -w 80% -h 80% -E "tmux attach-session -t \"$session\"" || exit 0

exit 0

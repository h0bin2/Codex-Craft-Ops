#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SESSION_NAME="${1:-ops}"

ensure_runtime_dirs

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux session already exists: $SESSION_NAME"
  echo "Attach with: tmux attach -t $SESSION_NAME"
  exit 0
fi

tmux new-session -d -s "$SESSION_NAME" -n pm -c "$REPO_ROOT"
tmux new-window -t "$SESSION_NAME" -n workers -c "$REPO_ROOT"
tmux new-window -t "$SESSION_NAME" -n review -c "$REPO_ROOT"
tmux new-window -t "$SESSION_NAME" -n monitor -c "$REPO_ROOT"

tmux send-keys -t "$SESSION_NAME:pm" \
  "printf 'PM window\\nUse: bash ops/scripts/pick-task.sh && bash ops/scripts/run-agent.sh pm-orchestrator <task-file>\\n'" C-m
tmux send-keys -t "$SESSION_NAME:workers" \
  "printf 'Implementer window\\nUse: bash ops/scripts/run-agent.sh implementer <task-file>\\n'" C-m
tmux send-keys -t "$SESSION_NAME:review" \
  "printf 'Reviewer window\\nUse: bash ops/scripts/run-agent.sh reviewer <task-file>\\n'" C-m
tmux send-keys -t "$SESSION_NAME:monitor" "bash ops/scripts/status-board.sh" C-m

echo "Created tmux session: $SESSION_NAME"
echo "Attach with: tmux attach -t $SESSION_NAME"

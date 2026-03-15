#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_runtime_dirs

print_once() {
  if [[ -t 1 && -n "${TERM:-}" ]]; then
    clear
  fi
  echo "Ops Status Board"
  echo "Updated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo "Task Counts"
  echo "  queued: $(print_status_summary "$TASKS_QUEUE_DIR")"
  echo "  doing:  $(print_status_summary "$TASKS_DOING_DIR")"
  echo "  done:   $(print_status_summary "$TASKS_DONE_DIR")"
  echo
  echo "Role States"

  for role in pm-orchestrator implementer reviewer; do
    state_file="$(state_file_for_role "$role")"

    if [[ -f "$state_file" ]]; then
      # shellcheck disable=SC1090
      source "$state_file"
      echo "  $role"
      echo "    task_id: ${task_id:-none}"
      echo "    status: ${status:-unknown}"
      echo "    last_update: ${last_update:-unknown}"
      echo "    last_output: ${last_output:-none}"
    else
      echo "  $role"
      echo "    status: idle"
    fi
  done

  echo
  echo "Recent Logs"
  recent_logs="$(find "$LOGS_DIR" -maxdepth 1 -type f ! -name '.gitkeep' | sort | tail -n 5)"
  if [[ -n "$recent_logs" ]]; then
    echo "$recent_logs" | sed 's#^#  - #'
  else
    echo "  - none"
  fi
}

if [[ "${NO_LOOP:-0}" == "1" ]]; then
  print_once
  exit 0
fi

while true; do
  print_once
  sleep 2
done

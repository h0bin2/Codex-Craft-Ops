#!/usr/bin/env bash

set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

TASK_INPUT="${1:-}"

[[ -n "$TASK_INPUT" ]] || die "Usage: bash ops/scripts/validate-task.sh <task-file>"

TASK_FILE="$(resolve_path "$TASK_INPUT")"
require_file "$TASK_FILE"
assert_valid_task_file "$TASK_FILE"

echo "Valid task: $TASK_FILE"

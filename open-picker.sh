#!/usr/bin/env bash
set -euo pipefail

herdr_bin="${HERDR_BIN_PATH:-herdr}"

env_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview|-p)     env_args+=(--env "ZOXIDE_PREVIEW=$2");  shift 2 ;;
    --depth|-d)       env_args+=(--env "ZOXIDE_DEPTH=$2");    shift 2 ;;
    --no-preview)     env_args+=(--env "ZOXIDE_NO_PREVIEW=1"); shift ;;
    --help|-h)
      echo "Usage: open-picker.sh [options]"
      echo "  --preview, -p  eza|tree|ls|<custom>  Preview tool"
      echo "  --depth, -d    N                      Tree depth"
      echo "  --no-preview                          Disable preview"
      exit 0 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

exec "$herdr_bin" plugin pane open \
  --plugin herdr-zoxide \
  --entrypoint picker \
  --placement overlay \
  ${env_args[@]+"${env_args[@]}"} \
  --focus

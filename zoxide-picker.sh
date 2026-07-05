#!/usr/bin/env bash
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────

CONFIG_FILE="${HERDR_PLUGIN_CONFIG_DIR}/config.toml"

DEPTH=2           # default
PREVIEW=          # empty = auto-detect
NO_PREVIEW=0

# Minimal flat-TOML reader (strings + ints). Ignores sections like [foo].
read_config() {
  local file="$1"
  [[ ! -f "$file" ]] && return 0
  while IFS='=' read -r key value; do
    # strip leading/trailing whitespace
    key="${key#"${key%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    # strip trailing inline comment
    value="${value%%#*}"
    # strip surrounding quotes
    value="${value#\"}"; value="${value%\"}"
    # skip blank values
    [[ -z "$value" ]] && continue
    case "$key" in
      preview) PREVIEW="$value" ;;
      depth)   DEPTH="$value"   ;;
    esac
  done < <(grep -v '^\s*#' "$file" | grep -F =)
}
read_config "$CONFIG_FILE"

# ─── Arg parse ───────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview|-p)
      PREVIEW="$2"; shift 2 ;;
    --depth|-d)
      DEPTH="$2";  shift 2 ;;
    --no-preview)
      NO_PREVIEW=1; shift ;;
    --help|-h)
      echo "Usage: zoxide-picker.sh [options]"
      echo "  --preview, -p  eza|tree|ls|<custom>  Preview tool"
      echo "  --depth, -d    N                      Tree depth (eza/tree only)"
      echo "  --no-preview                          Disable preview"
      echo ""
      echo "Config: $CONFIG_FILE"
      exit 0 ;;
    *)
      echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

# ─── Env overrides (from open-picker.sh --env forwarding) ────────────────────

[[ -n "${ZOXIDE_PREVIEW:-}"     ]] && PREVIEW="$ZOXIDE_PREVIEW"
[[ -n "${ZOXIDE_DEPTH:-}"       ]] && DEPTH="$ZOXIDE_DEPTH"
[[ -n "${ZOXIDE_NO_PREVIEW:-}"  ]] && NO_PREVIEW=1

# ─── Dependencies ────────────────────────────────────────────────────────────

for cmd in zoxide fzf; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "herdr-zoxide requires: $cmd" >&2
    echo "install it and try again" >&2
    read -rn1 -p $'press any key to close...' 2>/dev/null || sleep 3
    exit 1
  fi
done

# ─── Resolve preview command ─────────────────────────────────────────────────

build_preview_cmd() {
  local tool="$1" depth="$2"
  case "$tool" in
    eza)
      command -v eza >/dev/null 2>&1 || return 1
      printf 'eza -l --tree --level=%d --color=always {}' "$depth"
      return 0 ;;
    tree)
      command -v tree >/dev/null 2>&1 || return 1
      printf 'tree -C -L %d --dirsfirst {}' "$depth"
      return 0 ;;
    ls)
      printf 'ls -la {}'
      return 0 ;;
  esac
  return 1
}

preview_cmd=
if (( NO_PREVIEW )); then
  preview_cmd=
elif [[ -n "$PREVIEW" ]]; then
  # try as a named tool, else treat as a custom command string
  preview_cmd="$(build_preview_cmd "$PREVIEW" "$DEPTH")" || preview_cmd="$PREVIEW"
else
  # auto-detect: eza → tree → ls
  for tool in eza tree ls; do
    preview_cmd="$(build_preview_cmd "$tool" "$DEPTH")" && break
  done
fi

# ─── Fzf ─────────────────────────────────────────────────────────────────────

herdr_bin="${HERDR_BIN_PATH:-herdr}"
fzf_args=()

[[ -n "$preview_cmd" ]] && fzf_args+=(--preview "$preview_cmd")

zoxide query -l |
  fzf \
    --prompt="zoxide> " \
    --header=$'Enter: workspace \x1d ^T: tab \x1d ^S: split \x1d ^W: workspace (bg)' \
    "${fzf_args[@]}" \
    --bind "enter:become($herdr_bin workspace create --cwd {} --label \"\$(basename {})\" --focus)" \
    --bind "ctrl-t:become($herdr_bin tab create --cwd {} --label \"\$(basename {})\" --focus 2>/dev/null || $herdr_bin workspace create --cwd {} --label \"\$(basename {})\" --focus)" \
    --bind "ctrl-s:become($herdr_bin pane split --direction right --cwd {} --focus 2>/dev/null || $herdr_bin workspace create --cwd {} --label \"\$(basename {})\" --focus)" \
    --bind "ctrl-w:become($herdr_bin workspace create --cwd {} --label \"\$(basename {})\" --no-focus)"

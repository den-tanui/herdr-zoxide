# herdr-zoxide

Browse [zoxide](https://github.com/ajeetdsouza/zoxide) directories with [fzf](https://github.com/junegunn/fzf) preview and open them in Herdr as workspaces, tabs, or splits.

![demo](https://img.shields.io/badge/herdr-0.7.0%2B-blue)
![license](https://img.shields.io/badge/license-MIT-green)

## Features

- **Fuzzy-find** through your entire zoxide database — every directory you've ever `cd`'d to
- **Live preview** of directory structure via `eza`, `tree`, or `ls`
- **Choose your destination** — same picker, different keys for different actions
- **Configurable** — preview tool, tree depth, extra fzf flags all in a TOML config file
- **No lock-in** — works standalone outside Herdr too (`bash zoxide-picker.sh`)

## Requirements

| Tool | Required | Notes |
|------|----------|-------|
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Yes | Directory database. `zoxide init` must be set up. |
| [fzf](https://github.com/junegunn/fzf) | Yes | Fuzzy finder. Used for the interactive picker. |
| [Herdr](https://herdr.dev) 0.7.0+ | Yes | For plugin features. Picker works standalone without it. |

**Optional preview tools** (auto-detected, first found wins):

- [`eza`](https://github.com/eza-community/eza) — modern `ls` replacement with `--tree`
- [`tree`](https://linux.die.net/man/1/tree) — classic directory tree

If neither is installed, falls back to `ls -la`.

## Installation

### From GitHub

```bash
herdr plugin install den-tanui/herdr-zoxide
```

### Local development

```bash
git clone git@github.com:den-tanui/herdr-zoxide.git
cd herdr-zoxide
herdr plugin link .
```

### Verify

```bash
herdr plugin list
herdr plugin action list --plugin herdr-zoxide
```

## Usage

### Default keybinding suggestion

Add to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+o"
type = "plugin_action"
command = "herdr-zoxide.browse"
description = "Browse zoxide directories"
```

### What you see

Press `prefix+o` → an overlay pane opens with fzf showing your zoxide directories.
Type to filter. The right pane shows the selected directory's structure.

| Key | Action |
|-----|--------|
| `Enter` | New Herdr workspace, focused, named after the directory |
| `Ctrl-t` | New tab in current workspace (falls back to new workspace) |
| `Ctrl-s` | Split pane to the right, cwd set to directory (falls back to new workspace) |
| `Ctrl-w` | New Herdr workspace in background (no focus steal) |
| `Esc` / `Ctrl-c` | Close picker, do nothing |

### Running standalone (outside Herdr)

```bash
# With auto-detected preview
bash zoxide-picker.sh

# With flags
bash zoxide-picker.sh --preview tree --depth 3

# Disable preview
bash zoxide-picker.sh --no-preview
```

## Configuration

Plugin config lives in its own file — separate from Herdr's `config.toml`.

```bash
# Print the config directory path
herdr plugin config-dir herdr-zoxide
```

Create or edit `config.toml` in that directory:

```toml
# ~/.config/herdr/plugins/herdr-zoxide/config/config.toml

# Preview tool: "eza", "tree", "ls", or a custom command string.
# Unset = auto-detect (eza → tree → ls).
preview = "eza"

# Tree depth for eza/tree previews.
# Unset = 2.
depth = 3
```

### Custom preview command

```toml
# Any string that isn't "eza", "tree", or "ls" is treated as a
# shell command. {} is replaced with the selected directory.
preview = "bat --list-dirs --color=always {}"
```

## Flags reference

### `zoxide-picker.sh`

```text
Usage: zoxide-picker.sh [options]

  --preview, -p  eza|tree|ls|<custom>  Preview tool
  --depth, -d    N                      Tree depth (eza/tree only)
  --no-preview                          Disable preview
  --help, -h                            Show this message
```

### `open-picker.sh`

```text
Usage: open-picker.sh [options]

  --preview, -p  eza|tree|ls|<custom>  Preview tool
  --depth, -d    N                      Tree depth
  --no-preview                          Disable preview
  --help, -h                            Show this message
```

Flags on `open-picker.sh` are forwarded as environment variables to the pane,
where `zoxide-picker.sh` picks them up. CLI flags beat env vars beat config
file beat built-in defaults.

## How it works

```
Keybinding (prefix+o)
  └─► plugin_action "herdr-zoxide.browse"
       └─► open-picker.sh
            └─► herdr plugin pane open --entrypoint picker --placement overlay
                 └─► zoxide-picker.sh
                      ├─► read config.toml
                      ├─► parse flags / env overrides
                      ├─► zoxide query -l → pipe into fzf
                      │    └─► preview: eza | tree | ls | custom
                      └─► fzf become() → herdr workspace create | tab create | pane split
                           └─► overlay closes, user lands in destination
```

The plugin follows Herdr's standard **action-opens-pane** pattern (see
[Pattern 1 in the plugin development guide](https://herdr.dev/docs/plugins/)).
The action script is a thin wrapper around `herdr plugin pane open`. The pane
script does the real work: read config, launch fzf with zoxide data, then use
fzf's `become()` to replace the fzf process with the appropriate Herdr CLI
command. When the Herdr command exits, the overlay pane closes automatically.

## Troubleshooting

**Picker opens but shows no directories**
```bash
zoxide query -l | head
```
If this returns nothing, your zoxide database is empty. `cd` around a bit to
populate it, or add existing dirs with `zoxide add /some/path`.

**Preview shows "command not found"**
Your chosen preview tool (`eza` / `tree`) isn't installed. Either install it,
switch to a different one in config, or use `--no-preview`.

**"herdr: command not found" when selecting**
The `HERDR_BIN_PATH` env var isn't set (Herdr sets it automatically when
running the pane). If you're running `zoxide-picker.sh` standalone outside
Herdr, set it:
```bash
HERDR_BIN_PATH=/path/to/herdr bash zoxide-picker.sh
```

**Plugin action doesn't appear**
Make sure the plugin is enabled:
```bash
herdr plugin list
herdr plugin enable herdr-zoxide
```

**Check logs**
```bash
herdr plugin log list --plugin herdr-zoxide
```

## Development

```bash
git clone git@github.com:den-tanui/herdr-zoxide.git
cd herdr-zoxide
herdr plugin link .

# After editing, unlink and re-link, or just invoke the action again
herdr plugin action invoke herdr-zoxide.browse
```

## License

MIT

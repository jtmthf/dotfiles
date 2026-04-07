# Zsh Plugins

This repo manages zsh plugins without a plugin manager. Plugins are git-cloned directly into `zsh/plugins/` by `install.sh` and sourced in `.zshrc`. Updates are handled by the `update-all` shell function.

## Installed Plugins

### zsh-syntax-highlighting

**Source:** [github.com/zsh-users/zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)

Provides real-time syntax highlighting as you type commands. Valid commands appear green, unknown tokens appear red and bold, reserved words are cyan, options are magenta, quoted strings are yellow, redirections and globs are blue and bold, and paths are underlined.

**Important:** This plugin must be sourced last in `.zshrc`. Sourcing other plugins after it will break highlighting.

Configuration in `.zshrc`:

- **Highlighters:** `main`, `brackets`, `pattern`
- **Custom styles:** Over 30 token types are individually styled via `ZSH_HIGHLIGHT_STYLES`. See the `# zsh-syntax-highlighting` block in `.zshrc` for the full list.

### zsh-autosuggestions

**Source:** [github.com/zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)

Shows ghost text suggestions based on command history and completions as you type. Press the right arrow key to accept a suggestion.

Configuration in `.zshrc`:

| Variable | Value | Description |
|---|---|---|
| `ZSH_AUTOSUGGEST_STRATEGY` | `(history completion)` | Try history first, fall back to completion engine |
| `ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE` | `20` | Skip suggestions for inputs longer than 20 characters |
| `ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE` | `fg=#586e75` | Subtle gray for ghost text |
| `ZSH_AUTOSUGGEST_USE_ASYNC` | `1` | Fetch suggestions asynchronously |

### zsh-completions

**Source:** [github.com/zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions)

Adds completion definitions for many additional commands beyond what zsh ships with. This plugin is loaded by adding its `src/` directory to `fpath` before `compinit` runs -- it does not need to be sourced.

### zsh-history-substring-search (Homebrew)

**Source:** [github.com/zsh-users/zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search)

Unlike the other three plugins, this one is installed via Homebrew rather than git-cloned into `zsh/plugins/`. It is sourced from `$(brew --prefix)/share/zsh-history-substring-search/`.

Provides fuzzy history search by substring. Type part of a previous command and press the up arrow to cycle through matches.

Keybindings configured in `.zshrc`:

| Key | Action |
|---|---|
| Up arrow (`^[[A`) | Search history backward by substring |
| Down arrow (`^[[B`) | Search history forward by substring |
| Delete (`^[[3~`) | Delete character |
| Ctrl+R | Incremental reverse search |

The shell uses emacs keybinding mode (`bindkey -e`).

## Plugin Load Order

Plugins are sourced in `.zshrc` in this order:

1. **zsh-completions** -- fpath addition (before `compinit`)
2. **zsh-autosuggestions** -- sourced after `compinit`
3. **zsh-history-substring-search** -- sourced from Homebrew
4. **zsh-syntax-highlighting** -- sourced last (required by the plugin)

## How Plugins Are Managed

### Installation

`install.sh` calls `setup_zsh_plugins()`, which clones each plugin repo into `zsh/plugins/` if it does not already exist:

```bash
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git zsh/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions.git zsh/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-completions.git zsh/plugins/zsh-completions
```

The `zsh/plugins/` directory is gitignored -- plugins are not checked into this repo.

### Updating

Run `update-all` in your shell. This function (defined in `zsh/functions.zsh`) iterates over every directory in `zsh/plugins/` that contains a `.git` folder and runs `git pull`:

```bash
update-all
```

This also updates Homebrew packages (including zsh-history-substring-search) and Mise runtimes.

### Adding a New Plugin

1. Add a clone block to `setup_zsh_plugins()` in `install.sh`:

    ```bash
    if [[ ! -d "$plugins_dir/new-plugin" ]]; then
        run git clone https://github.com/author/new-plugin.git "$plugins_dir/new-plugin"
    fi
    ```

2. Source or load the plugin in `zsh/.zshrc`. If it provides completions, add its path to `fpath` before `compinit`. If it is a standard plugin, source its main `.zsh` file after `compinit`.

3. If the plugin must be sourced before syntax highlighting, place it above the `# zsh-syntax-highlighting` block.

4. Run `./install.sh` to clone the new plugin, then `exec zsh` to reload.

### Removing a Plugin

1. Delete the clone block from `install.sh`.
2. Remove the `source` or `fpath` line from `.zshrc`.
3. Delete the plugin directory: `rm -rf zsh/plugins/plugin-name`.
4. Run `exec zsh` to reload.

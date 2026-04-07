# Completions

The completion system has two layers: the built-in zsh completion engine configured in `.zshrc`, and a caching layer in `zsh/completions.zsh` that generates and stores tool-specific completions for fast startup.

## How compinit works

`.zshrc` calls `autoload -Uz compinit` and uses a smart rebuild strategy. The dump file (`$ZDOTDIR/.zcompdump`) is only regenerated when its mtime is older than 24 hours. On all other shell startups, `compinit -C` skips the expensive function scan entirely. When the dump is rebuilt, it is compiled with `zcompile` so subsequent loads read a binary `.zwc` file instead of parsing text.

## Completion styling

The `zstyle` block in `.zshrc` configures the completion UI:

| Setting | Effect |
|---|---|
| `menu select` | Interactive menu you can navigate with arrow keys |
| `matcher-list` | Case-insensitive matching, plus partial-word and substring matching |
| `list-colors` | Colored candidates using `LS_COLORS` |
| `use-cache` / `cache-path` | Expensive completions (e.g., remote package lists) are cached in `$XDG_CACHE_HOME/zsh/zcompcache` |
| `processes` / `kill` | `kill` tab-completion shows running processes with color-coded PIDs |
| `descriptions` / `corrections` / `messages` / `warnings` | Formatted group headers and error messages in the completion menu |

## Cached completion generation

`zsh/completions.zsh` avoids running slow `<tool> completion zsh` commands on every shell startup. The `_cache_completion` helper does this:

1. Checks whether the tool binary exists (via `$commands`).
2. Compares the mtime of the binary against the cached output file in `$XDG_CACHE_HOME/zsh/completions/`.
3. Regenerates the cache only when the binary is newer than the cache (i.e., the tool was upgraded) or the cache file does not exist yet.
4. Sources the cached file.

This means completion scripts are generated once per tool install/upgrade and loaded from disk on every subsequent startup -- typically a sub-millisecond read instead of a 50-200ms subprocess.

### Tools with cached completions

| Tool | Generation command |
|---|---|
| gh | `gh completion -s zsh` |
| docker | `docker completion zsh` |
| kubectl | `kubectl completion zsh` |
| helm | `helm completion zsh` |
| mise | `mise completion zsh` |

### Special cases

- **Terraform** uses the bash-compatible `complete -o nospace -C terraform terraform` mechanism instead of generating a zsh script.
- **zsh-completions plugin** is loaded in `.zshrc` before `completions.zsh`. It adds community-maintained completions for hundreds of tools via its `src/` directory on `fpath`.
- **FZF** has its own completion file loaded separately in `.zshrc` from `$HOMEBREW_PREFIX/opt/fzf/shell/completion.zsh`.

## Custom completions for dotfiles functions

Several shell functions defined in `functions.zsh` have hand-written completions registered with `compdef`:

| Function | Completion behavior |
|---|---|
| `extract` | Suggests archive files (`*.tar.gz`, `*.zip`, `*.rar`, `*.7z`, etc.) |
| `backup` | Suggests any file |
| `port-check` | Accepts a port number |
| `port-kill` | Accepts a port number |

## Alias completions

Aliases inherit the completion of their target command via `compdef`:

```zsh
compdef g=git
compdef v=nvim
compdef c=code
```

Typing `g checkout <TAB>` produces the same branch completions as `git checkout <TAB>`.

## Adding a new cached completion

To add completions for a new CLI tool:

1. Find the tool's completion generation command (usually `<tool> completion zsh` -- check `<tool> --help`).
2. Add a line to `zsh/completions.zsh`:

```zsh
_cache_completion <name> <binary> <generation command...>
```

For example, to add `rg` (ripgrep) completions:

```zsh
_cache_completion rg rg rg --generate complete-zsh
```

3. Reload your shell with `exec zsh`. The completion file will be generated on the first load and cached for future sessions.

If the tool does not support generating zsh completions, you can write a custom completion function and register it with `compdef` instead, following the pattern used for `extract` and `backup`.

## Adding an alias completion

If you create a new alias for a command that already has completions, add a `compdef` line at the bottom of `completions.zsh`:

```zsh
compdef myalias=originalcommand
```

## Performance impact

Without caching, generating completions for all tools at startup adds roughly 200-500ms (each `<tool> completion zsh` call spawns a subprocess). With the mtime-based cache, those calls only happen once per tool upgrade, and startup loads pre-generated files from disk in under 1ms total. Combined with the once-per-day `compinit` rebuild and `zcompile`, the full completion system adds negligible time to shell startup.

# Starship Prompt

Starship is a fast, minimal, cross-shell prompt written in Rust. The configuration lives at `config/starship.toml` and is symlinked to `~/.config/starship.toml` by the installer. It is initialized in `.zshrc` via `eval "$(starship init zsh)"`.

## Prompt layout

The prompt spans two lines:

```
[username] [hostname] [directory] [git_branch] [git_status] [languages...] [infra...] [cmd_duration]
[character]
```

Line 1 shows context-dependent segments. Most segments only appear when relevant (inside a git repo, in a directory with matching project files, connected over SSH, etc.). Line 2 is always the prompt character.

`add_newline` is set to `false`, so there is no blank line inserted before each prompt.

## Modules

### Character

The prompt symbol is `❯`. It renders bold green after a successful command and bold red after a failure.

### Directory

| Setting | Value |
|---|---|
| Style | bold cyan |
| Truncation length | 3 levels |
| Truncate to repo | yes |
| Truncation symbol | `.../` |

When inside a git repository the path is truncated relative to the repo root, keeping the display compact.

### Git branch

Displayed with a ` ` symbol in bold purple. Appears whenever the working directory is inside a git repository.

### Git status

Styled in red. Custom symbols replace the defaults:

| Symbol | Meaning |
|---|---|
| `⇡${count}` | Commits ahead of remote |
| `⇣${count}` | Commits behind remote |
| `⇕⇡${ahead}⇣${behind}` | Diverged from remote |
| `x` | Deleted files |

### Node.js

Symbol `⬢`, bold green. Shown when the directory contains `package.json` or `.nvmrc`.

### Python

Symbol ` `, bold yellow. Detected by `.py` file extensions and by the presence of `requirements.txt`, `.python-version`, `pyproject.toml`, or `Pipfile`.

### Java

Symbol `☕`, red dimmed. Detected by Starship's built-in heuristics (`.java`, `pom.xml`, `build.gradle`, etc.).

### Ruby

Symbol `💎`, bold red. Detected by Starship's built-in heuristics (`Gemfile`, `.ruby-version`, `*.rb`, etc.).

### Go

Symbol ` `, bold cyan. Detected by Starship's built-in heuristics (`go.mod`, `*.go`, etc.).

### Rust

Symbol ` `, bold red. Detected by Starship's built-in heuristics (`Cargo.toml`, `*.rs`, etc.).

### Docker context

Symbol ` `, blue bold. Only shown when Docker-related files are present in the directory (`only_with_files = true`).

### Kubernetes

Symbol `☸`, cyan bold. Explicitly enabled (`disabled = false` -- Starship disables it by default). Shows the current kubectl context.

### AWS

Symbol `  `, bold yellow. Shows the active AWS profile or region when set.

### Google Cloud

Symbol `☁️`, bold blue. Shows the active gcloud configuration when set.

### Terraform

Symbol `💠`, bold purple. Shown when Terraform files are detected.

### Command duration

Displayed for any command that takes longer than 2 seconds (`min_time = 2_000`ms). Styled yellow bold, formatted as `took [duration]`.

### Username

Styled bold dimmed blue. Only displayed when the current user is not the default logged-in user (`show_always = false`).

### Hostname

Styled bold dimmed green. Only displayed during SSH sessions (`ssh_only = true`).

## Customizing

Edit `config/starship.toml` directly. After saving, changes take effect on the next prompt render -- no shell restart required.

Common adjustments:

- **Show more directory levels** -- increase `truncation_length` under `[directory]`.
- **Always show username** -- set `show_always = true` under `[username]`.
- **Disable a module** -- add `disabled = true` to its section (e.g., `[kubernetes]`).
- **Change symbols or colors** -- modify `symbol` and `style` in the relevant section. Starship supports named colors (`red`, `bold cyan`) and hex values (`#ff5733`).

Full configuration reference: <https://starship.rs/config/>

## Performance

`scan_timeout` is set to 10ms, which limits how long Starship spends scanning the working directory for file-detection triggers. This keeps prompt rendering fast even in large repositories. If a language module fails to appear in a very large directory tree, increasing this value (default is 30ms) may help at the cost of slightly slower prompts.

Starship itself is a compiled Rust binary, so prompt latency is typically under 10ms for most modules. The Kubernetes module can add measurable latency if the kubeconfig is on a slow filesystem or references a remote API server -- disable it with `disabled = true` if that becomes an issue.

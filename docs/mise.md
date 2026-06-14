# Mise

Mise (formerly rtx) is a polyglot runtime and tool version manager. It replaces nvm, pyenv, rbenv, and similar single-language version managers with one tool that handles all of them.

## Installation

Mise is installed as a Homebrew formula via the Brewfile:

```ruby
brew "mise"
```

The installer (`install.sh`) symlinks the configuration file into place:

```
config/mise/config.toml  -->  ~/.config/mise/config.toml
```

## Configuration

The global config at `config/mise/config.toml` declares which language runtimes to install and pins their versions:

```toml
[tools]
node = "lts"
python = "3.14"
java = "openjdk-25"
ruby = "3.2"

# Global CLIs via mise backends (replaces the deprecated default_packages_file)
"npm:typescript-language-server" = "latest"
"pipx:crawl4ai" = "latest"

[env]
EDITOR = "nvim"
PAGER = "bat"
# uv reuses mise's managed Python instead of downloading its own
UV_PYTHON_PREFERENCE = "only-system"

[settings]
auto_install = true
idiomatic_version_file_enable_tools = ["node", "python", "java", "ruby"]
# Auto-create/source a uv-managed .venv when entering a project
python.uv_venv_auto = "create|source"
```

### Managed languages

| Tool | Version | Notes |
|------|---------|-------|
| Node.js | `lts` | Tracks the current LTS release |
| Python | `3.14` | Pinned minor version |
| Java | `openjdk-25` | OpenJDK |
| Ruby | `3.2` | Pinned minor version |

### Global CLI tools

Cross-language CLIs are declared directly in `[tools]` using mise's language backends -- `npm:` for Node packages and `pipx:` for Python packages. This replaces the older `default_packages_file` mechanism, which mise has deprecated. Each entry is installed and version-managed like any other tool, e.g. `"pipx:crawl4ai" = "latest"`.

### uv integration

`uv` (installed via Homebrew) handles Python virtualenvs, and mise is configured to cooperate with it:

- **`python.uv_venv_auto = "create|source"`** -- when you enter a project, mise creates a uv-managed `.venv` if missing and sources it automatically (requires `mise activate`).
- **`UV_PYTHON_PREFERENCE = "only-system"`** -- uv uses the Python on `PATH` (mise's managed interpreter) instead of downloading its own, so mise stays the single source of truth for Python versions.

### Settings

- **auto_install** -- Mise automatically installs a missing runtime version when you `cd` into a project that requires it.
- **idiomatic_version_file_enable_tools** -- Opt-in list of tools for which mise respects idiomatic version files (`.nvmrc`, `.python-version`, `.ruby-version`, etc.). Enabled here for node, python, java, and ruby, so existing projects that use nvm, pyenv, or rbenv version files work without changes. (This per-tool setting replaces the old global `legacy_version_file` flag.)

### Environment variables

The `[env]` section sets global environment variables through mise, keeping editor and pager preferences centralized alongside tool versions.

## Dual activation strategy

Mise is activated in two different places in the zsh config, each serving a different purpose:

1. **`.zprofile` (login shells)** -- `mise activate zsh --shims`

   Shim-based activation places lightweight wrapper scripts on `$PATH`. This is fast, does not hook into the shell, and works for non-interactive contexts like scripts, cron jobs, IDE terminals, and `ssh` commands. Shims always resolve to whatever version is configured for the current directory.

2. **`.zshrc` (interactive shells)** -- `mise activate zsh`

   Full hook-based activation installs a `chpwd` hook so mise detects directory changes in real time. When you `cd` into a project with a `.tool-versions` or `.nvmrc` file, mise immediately switches to the correct runtime version without needing to spawn a new shell. This mode also enables `auto_install`.

The two modes complement each other: shims provide broad coverage for non-interactive use, while hooks give instant feedback during interactive work.

### Supporting configuration

- **`.zshenv`** -- Sets XDG-compliant directories so mise data, config, and cache go to the right places (`MISE_DATA_DIR`, `MISE_CONFIG_DIR`, `MISE_CACHE_DIR`).
- **`completions.zsh`** -- Generates and caches mise shell completions, regenerating only when the mise binary changes.

## Aliases

Shell aliases are defined in `zsh/aliases.zsh` for common mise operations:

| Alias | Command | Purpose |
|-------|---------|---------|
| `mi`  | `mise` | Shorthand for mise |
| `mii` | `mise install` | Install a tool version |
| `mil` | `mise list` | List installed versions |
| `miu` | `mise use` | Set tool version for current directory |
| `mir` | `mise remove` | Remove an installed version |

The `update-all` shell function (in `zsh/functions.zsh`) includes `mise upgrade` as part of its system-wide update sweep.

## Adding a new tool

1. Add the tool and version to `config/mise/config.toml` under `[tools]`:

   ```toml
   [tools]
   go = "1.22"
   ```

2. Run `mise install` (or just `cd` into a directory -- `auto_install` will handle it).

3. Verify with `mise list` or `mise current`.

For project-specific versions, create a `.mise.toml` or `.tool-versions` file in the project root instead of editing the global config:

```bash
# Pin a version for just the current project
mise use node@20
```

This writes a `.mise.toml` in the current directory, which takes precedence over the global config. Because idiomatic version files are enabled (see `idiomatic_version_file_enable_tools`), you can also use `.nvmrc`, `.python-version`, or any other idiomatic format your team already relies on.

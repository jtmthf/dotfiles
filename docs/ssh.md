# SSH

SSH configuration lives at `config/ssh/config` and is included by `~/.ssh/config`, which the installer generates as a real file (not a symlink).

Requires OpenSSH >= 7.3 for `Include` directive support.

## Config structure

`~/.ssh/config` is a generated file written by the installer containing a single `Include` line pointing to the dotfiles config. This means tools like 1Password can append host entries to `~/.ssh/config` without touching source-controlled files.

The dotfiles config itself is split into three layers using `Include`:

1. **`~/.config/colima/ssh_config`** — Colima-managed VM entries, included if present (silently ignored otherwise).
2. **`~/.ssh/config.local`** — platform-specific settings written by the installer at install time (see below).
3. **`Host *` defaults** — connection keep-alive, multiplexing, and security settings applied to all hosts.

## Default host settings

| Setting                | Value                       | Purpose                                      |
|------------------------|-----------------------------|----------------------------------------------|
| `ServerAliveInterval`  | 60                          | Send keepalive every 60 seconds              |
| `ServerAliveCountMax`  | 3                           | Drop connection after 3 missed keepalives    |
| `ControlMaster`        | auto                        | Reuse existing connection if one exists      |
| `ControlPath`          | `~/.ssh/control/%r@%h:%p`  | Socket path for multiplexed connections      |
| `ControlPersist`       | 10m                         | Keep master connection alive for 10 minutes  |
| `AddKeysToAgent`       | yes                         | Automatically add keys to the SSH agent      |

The `~/.ssh/control/` directory is created with `chmod 700` by the installer.

## Platform-specific config.local

The installer writes `~/.ssh/config.local` with the correct `IdentityAgent` path for 1Password SSH agent:

| Platform      | IdentityAgent path                                                              |
|---------------|---------------------------------------------------------------------------------|
| macOS         | `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`             |
| Linux / WSL   | `~/.1password/agent.sock`                                                       |

This file is written at install time so SSH does not need to exec `uname` on every connection.

## Reinstalling

The installer is idempotent for `~/.ssh/config`. On reinstall it checks whether the `Include` directive is already present:

- If yes — the file is left untouched, preserving any entries added by tools like 1Password.
- If no — the `Include` is prepended to the existing content.

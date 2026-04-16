# SSH

SSH configuration lives at `config/ssh/config` and is symlinked to `~/.ssh/config` by the installer.

Requires OpenSSH >= 7.3 for `Include` directive support.

## Config structure

The config is split into three layers using `Include`:

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

## Symlinked config caveat

`~/.ssh/config` is a symlink. Some hardened OpenSSH builds (certain Linux distros with strict `ControlPath` checks) may reject symlinked configs. If SSH silently ignores the config, copy it instead:

```bash
cp config/ssh/config ~/.ssh/config
```

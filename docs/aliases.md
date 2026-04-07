# Shell Aliases

All aliases are defined in `zsh/aliases.zsh`. Where a modern replacement tool is used (eza, bat, duf, lazygit, lazydocker), the alias gates on `command -v` so it only activates when the tool is installed. If the tool is missing, the alias either falls back to the standard command or is simply not defined.

macOS-specific aliases are guarded by an `$OSTYPE == darwin*` check and are not loaded on Linux.

---

## Navigation

| Alias   | Command            |
|---------|--------------------|
| `..`    | `cd ..`            |
| `...`   | `cd ../..`         |
| `....`  | `cd ../../..`      |
| `.....` | `cd ../../../..`   |
| `~`     | `cd ~`             |
| `-`     | `cd -`             |

## Listing Files (eza / ls)

When `eza` is installed these aliases use it; otherwise they fall back to plain `ls --color=auto`.

| Alias | With eza                              | Fallback        |
|-------|---------------------------------------|-----------------|
| `ls`  | `eza --group-directories-first`       | `ls --color=auto` |
| `la`  | `eza -la --group-directories-first`   | `ls -la`        |
| `ll`  | `eza -l --group-directories-first`    | `ls -l`         |
| `lt`  | `eza --tree --level=2`                | not defined     |
| `lta` | `eza --tree --level=2 -a`             | not defined     |

## Cat (bat)

Defined only when `bat` is installed.

| Alias  | Command        |
|--------|----------------|
| `cat`  | `bat`          |
| `catp` | `bat --plain`  |

## Disk Free (duf)

Defined only when `duf` is installed.

| Alias | Command |
|-------|---------|
| `df`  | `duf`   |

## Git

| Alias | Command                        |
|-------|--------------------------------|
| `g`   | `git`                          |
| `ga`  | `git add`                      |
| `gaa` | `git add .`                    |
| `gc`  | `git commit`                   |
| `gcm` | `git commit -m`                |
| `gca` | `git commit -am`               |
| `gp`  | `git push`                     |
| `gpl` | `git pull`                     |
| `gs`  | `git status`                   |
| `gd`  | `git diff`                     |
| `gb`  | `git branch`                   |
| `gco` | `git checkout`                 |
| `gcb` | `git checkout -b`              |
| `gm`  | `git merge`                    |
| `gr`  | `git rebase`                   |
| `gl`  | `git log --oneline --graph`    |
| `gla` | `git log --oneline --graph --all` |
| `gst` | `git stash`                    |
| `gsp` | `git stash pop`                |
| `lg`  | `lazygit` (requires lazygit)   |

## Docker

| Alias   | Command             |
|---------|---------------------|
| `d`     | `docker`            |
| `dc`    | `docker-compose`    |
| `dps`   | `docker ps`         |
| `dpsa`  | `docker ps -a`      |
| `di`    | `docker images`     |
| `drmi`  | `docker rmi`        |
| `drm`   | `docker rm`         |
| `dexec` | `docker exec -it`   |
| `dlogs` | `docker logs`       |
| `dstop` | `docker stop`       |
| `dstart`| `docker start`      |
| `ld`    | `lazydocker` (requires lazydocker) |

## Development

| Alias   | Command                    |
|---------|----------------------------|
| `v`     | `nvim`                     |
| `vim`   | `nvim`                     |
| `c`     | `code`                     |
| `py`    | `python3`                  |
| `pip`   | `pip3`                     |
| `serve` | `python3 -m http.server`   |
| `json`  | `python3 -m json.tool`     |

## Network

| Alias  | Command              |
|--------|----------------------|
| `ping` | `ping -c 5`          |
| `wget` | `wget -c`            |
| `myip` | `curl ifconfig.me`   |
| `ports`| `netstat -tulanp`    |

## System

| Alias    | Command                           |
|----------|-----------------------------------|
| `h`      | `history`                         |
| `j`      | `jobs`                            |
| `path`   | Pretty-print `$PATH` (one entry per line) |
| `reload` | `exec zsh`                        |
| `cls`    | `clear`                           |

## Archives

| Alias   | Command        |
|---------|----------------|
| `tgz`   | `tar -czf`    |
| `untgz` | `tar -xzf`    |
| `tbz`   | `tar -cjf`    |
| `untbz` | `tar -xjf`    |

## macOS Only

These aliases are only loaded on macOS (`darwin*`).

| Alias           | Description                                      |
|-----------------|--------------------------------------------------|
| `flush`         | Flush DNS cache and restart mDNSResponder        |
| `lscleanup`    | Reset Launch Services database and restart Finder |
| `show`          | Show hidden files in Finder                      |
| `hide`          | Hide hidden files in Finder                      |
| `showdesktop`   | Show desktop icons                               |
| `hidedesktop`   | Hide desktop icons                               |
| `airport`       | Access the Airport CLI utility                   |
| `emptytrash`    | Empty Trash, system logs, and quarantine history |

## Homebrew

| Alias | Command                      |
|-------|------------------------------|
| `br`  | `brew`                       |
| `bri` | `brew install`               |
| `brs` | `brew search`                |
| `bro` | `brew outdated`              |
| `bru` | `brew update && brew upgrade`|
| `brc` | `brew cleanup`               |

## Mise

| Alias | Command        |
|-------|----------------|
| `mi`  | `mise`         |
| `mii` | `mise install` |
| `mil` | `mise list`    |
| `miu` | `mise use`     |
| `mir` | `mise remove`  |

## Utility

| Alias          | Description                                  |
|----------------|----------------------------------------------|
| `week`         | Print current ISO week number                |
| `timer`        | Simple stopwatch (stop with Ctrl-D)          |
| `urlencode`    | URL-encode a string argument                 |
| `urldecode`    | URL-decode a string argument                 |
| `base64encode` | Base64-encode a string argument              |
| `base64decode` | Base64-decode a string argument              |

## File Operations

| Alias   | Command      |
|---------|--------------|
| `mk`    | `mkdir -p`   |
| `md`    | `mkdir -p`   |
| `rd`    | `rmdir`      |
| `rf`    | `rm -rf`     |

## Process Management

| Alias     | Command            |
|-----------|--------------------|
| `psg`     | `ps aux \| grep`   |
| `killall` | `killall -v`       |

## Quick Edits

Open configuration files in nvim.

| Alias       | File                          |
|-------------|-------------------------------|
| `zshrc`     | `$ZDOTDIR/.zshrc`            |
| `aliases`   | `$DOTFILES/zsh/aliases.zsh`  |
| `functions` | `$DOTFILES/zsh/functions.zsh`|

## Quick Navigation

| Alias  | Directory       |
|--------|-----------------|
| `dl`   | `~/Downloads`   |
| `dt`   | `~/Desktop`     |
| `docs` | `~/Documents`   |
| `dev`  | `~/Development` |
| `proj` | `~/Projects`    |

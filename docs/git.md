# Git

Global git configuration lives at `config/git/config` and is symlinked to `~/.config/git/config` by the installer.

## Config highlights

**Delta pager** — diffs are rendered by [delta](https://github.com/dandavison/delta) with side-by-side view and line numbers. The interactive diff filter also uses delta for `git add -p`.

**Histogram diff** — `diff.algorithm = histogram` produces more readable diffs for refactored code than the default Myers algorithm.

**Merge conflict style** — `zdiff3` includes the common ancestor in conflict markers, making conflicts easier to resolve.

**Rebase defaults** — `autoSquash = true` automatically applies `fixup!` / `squash!` commits, and `autoStash = true` stashes dirty state before rebasing and pops it after.

**Push / pull** — `push.autoSetupRemote` and `push.default = current` mean `git push` works without `-u origin branch`. Pull uses rebase by default.

**Prune on fetch** — remote-tracking branches and tags deleted upstream are pruned automatically.

**Rerere** — reuse recorded resolutions; repeated merge conflicts are resolved automatically after the first manual fix.

**SSH commit signing** — commits and tags are signed with SSH keys via 1Password. See [SSH](#ssh-signing) below.

## Local overrides

The installer creates `~/.config/git/config.local` (empty by default) and includes it at the top of the global config. Set these fields before making commits:

```
[user]
    name = Your Name
    email = you@example.com
    signingKey = ssh-ed25519 AAAA...
```

The installer prints a warning reminding you to fill this in.

## Global gitignore

`config/git/ignore` is symlinked to `~/.config/git/ignore` and covers:

- macOS metadata (`.DS_Store`, `.AppleDouble`)
- Editor artifacts (`.idea/`, `*.swp`, `*.swo`, `*~`)
- Secrets (`.env`)
- Logs and backups

## SSH signing

`commit.gpgSign` and `tag.gpgSign` are enabled by default. The signing format is `ssh`, so no GPG daemon is required.

`gpg.ssh.allowedSignersFile` points to `~/.ssh/allowed_signers`. This file is created empty by the installer. Add trusted public keys here to verify others' signed commits with `git log --show-signature`.

The `signingKey` itself must be set in `~/.config/git/config.local` (see above).

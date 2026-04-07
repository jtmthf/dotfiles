# Shell Functions Reference

All functions are defined in `zsh/functions.zsh` and loaded automatically with every shell session. Many functions use enhanced tools when available (e.g., `hyperfine`, `tokei`, `dust`) and fall back to standard utilities otherwise.

---

## File Operations

### `mkcd`

Create a directory (including intermediate parents) and cd into it.

```
mkcd <directory>
```

**Example:**

```bash
mkcd ~/Projects/new-app/src
# Creates ~/Projects/new-app/src and changes into it
```

---

### `extract`

Extract any common archive format. Automatically detects the format from the file extension.

```
extract <archive>
```

**Supported formats:** `.tar.bz2`, `.tar.gz`, `.bz2`, `.rar`, `.gz`, `.tar`, `.tbz2`, `.tgz`, `.zip`, `.Z`, `.7z`

**Example:**

```bash
extract project.tar.gz
extract backup.zip
extract data.7z
```

---

### `findreplace`

Find and replace text across files matching a pattern, recursively from the current directory. Requires [`sd`](https://github.com/chmln/sd).

```
findreplace <search_pattern> <replace_pattern> <file_pattern>
```

**Example:**

```bash
findreplace 'http://' 'https://' '*.html'
findreplace 'oldFunction' 'newFunction' '*.js'
```

---

### `backup`

Create a timestamped copy of a file in the same directory.

```
backup <file>
```

The backup is named `<file>.backup.YYYYMMDD_HHMMSS`.

**Example:**

```bash
backup ~/.zshrc
# Creates ~/.zshrc.backup.20260406_143022
```

---

### `filesize`

Display the size of a file or directory in human-readable format. Uses `dust` if installed, otherwise falls back to `du -sh`.

```
filesize <file>
```

**Example:**

```bash
filesize node_modules
filesize database.sql
```

---

### `findlarge`

Find files larger than a given size in the current directory tree, sorted by size descending. Defaults to 100M.

```
findlarge [size]
```

**Example:**

```bash
findlarge          # Files larger than 100M
findlarge 50M      # Files larger than 50M
findlarge 1G       # Files larger than 1G
```

---

## Development

### `dev-setup`

Scaffold a new project directory with a standard structure: `src/`, `tests/`, `docs/`, a `README.md`, and a `.gitignore` with common ignore patterns. Initializes a git repository. Defaults to the name `new-project` if none is given.

```
dev-setup [project_name]
```

**Example:**

```bash
dev-setup my-cli-tool
# Creates my-cli-tool/ with git init, src/, tests/, docs/, README.md, .gitignore
```

The generated `.gitignore` covers dependencies (`node_modules/`, `venv/`), build outputs (`dist/`, `build/`, `__pycache__/`), IDE files (`.vscode/`, `.idea/`), and OS files (`.DS_Store`, `Thumbs.db`).

---

### `codestats`

Show code statistics for the current directory. Uses `tokei` if installed, otherwise counts lines across `.py`, `.js`, `.go`, `.rs`, and `.java` files with `wc -l`.

```
codestats
```

**Example:**

```bash
cd ~/Projects/my-app
codestats
```

---

### `bench`

Benchmark a command. Uses `hyperfine` for statistical benchmarks if installed, otherwise falls back to `time`.

```
bench <command>
```

**Example:**

```bash
bench 'fd --type f'
bench 'grep -r TODO .'
```

---

## Git

### `git-cleanup`

Clean up the current git repository: delete local branches that have been merged (excluding `main`, `master`, and `develop`), prune stale remote-tracking references, and run garbage collection.

```
git-cleanup
```

---

### `git-contributors`

List all unique contributors (name and email) from the git log.

```
git-contributors
```

**Example output:**

```
Alice Smith <alice@example.com>
Bob Jones <bob@example.com>
```

---

### `git-stats`

Display repository statistics: total commits, total contributors, repository size on disk, and the top 10 contributors by commit count.

```
git-stats
```

**Example output:**

```
Repository Statistics:
=====================
Total commits: 347
Total contributors: 5
Repository size: 12M

Top 10 contributors:
   210 Alice Smith
    85 Bob Jones
    52 Carol Lee
```

---

## Docker

### `docker-cleanup`

Aggressively prune Docker resources: removes all unused containers, networks, images (including untagged), and volumes.

```
docker-cleanup
```

**Warning:** This removes all unused images and volumes, not just dangling ones. Data in unnamed volumes will be lost.

---

### `docker-stop-all`

Stop every running Docker container.

```
docker-stop-all
```

---

### `docker-rm-all`

Remove every Docker container (running or stopped).

```
docker-rm-all
```

---

## Network

### `localip`

Print the machine's local IP address. Uses `ipconfig` on macOS and `hostname -I` on Linux.

```
localip
```

**Example output:**

```
192.168.1.42
```

---

### `port-check`

Show what process is using a given port.

```
port-check <port>
```

**Example:**

```bash
port-check 3000
port-check 8080
```

---

### `port-kill`

Kill whatever process is listening on a given port (sends `SIGKILL`).

```
port-kill <port>
```

**Example:**

```bash
port-kill 3000
```

---

## System

### `sysinfo`

Display system information: OS, kernel version, architecture, hostname, uptime, and memory usage. On macOS, also shows the macOS version and physical memory from `top`. On Linux, shows memory from `free`.

```
sysinfo
```

**Example output (macOS):**

```
System Information:
==================
OS: Darwin
Kernel: 25.3.0
Architecture: arm64
Hostname: macbook.local
Uptime: 3 days
macOS Version: 15.4
Memory: 12G
```

---

### `watch-process`

Continuously monitor a process by name, refreshing every second. Uses `watch` with `ps aux`.

```
watch-process <name>
```

**Example:**

```bash
watch-process node
watch-process postgres
```

Press `Ctrl+C` to stop.

---

### `update-all`

Update Homebrew (update, upgrade, cleanup), Mise runtimes, and any zsh plugins cloned as git repositories under `~/.dotfiles/zsh/plugins/`. Each tool is skipped if not installed.

```
update-all
```

---

## Utilities

### `genpass`

Generate a random password using `openssl`. Defaults to 16 characters.

```
genpass [length]
```

**Example:**

```bash
genpass        # 16-character password
genpass 32     # 32-character password
```

---

### `weather`

Fetch a compact weather summary from [wttr.in](https://wttr.in). If no location is given, wttr.in infers it from your IP.

```
weather [location]
```

**Example:**

```bash
weather              # Weather for current location
weather "New York"   # Weather for New York
weather Tokyo        # Weather for Tokyo
```

---

### `qr`

Generate a QR code in the terminal using [qrenco.de](https://qrenco.de).

```
qr <text>
```

**Example:**

```bash
qr "https://github.com"
qr "Hello, world!"
```

---

### `json-pretty`

Pretty-print JSON using Python's `json.tool`. Reads from a file if provided, otherwise reads from stdin.

```
json-pretty [file]
```

**Example:**

```bash
json-pretty data.json
curl -s https://api.example.com/data | json-pretty
```

---

### `yaml-pretty`

Pretty-print YAML using `yq`. Reads from a file if provided, otherwise reads from stdin. Requires [`yq`](https://github.com/mikefarah/yq).

```
yaml-pretty [file]
```

**Example:**

```bash
yaml-pretty config.yml
cat values.yaml | yaml-pretty
```

# Services

Development services (PostgreSQL and Redis) are installed via the Brewfile as standard formulae and configured on demand by `scripts/setup-services.zsh`. This script is **not** run automatically by `install.sh` — run it manually after install: `zsh scripts/setup-services.zsh`.

## How services are started

PostgreSQL and Redis are plain `brew` formulae in the Brewfile — they are not registered to auto-start. Run `scripts/setup-services.zsh` to bring them up: it checks whether each service is already running, starts any that are not with `brew services`, and performs first-run initialization (creating the default database for PostgreSQL, verifying connectivity for Redis). Once started, `brew services` keeps them running across logins.

(For contrast, Ollama declares `start_service: true` in the Brewfile, so `brew bundle` starts it automatically during install.)

## PostgreSQL

Installed as `postgresql@17`.

| Detail | Value |
|--------|-------|
| Host | `localhost` |
| Port | `5432` |
| Database | `$USER` (your macOS username) |
| User | `$USER` |

The setup script creates a default database named after the current user if one does not already exist.

```bash
# Connect to the default database
psql -h localhost -U $USER -d $USER
```

## Redis

Installed as `redis`.

| Detail | Value |
|--------|-------|
| Host | `localhost` |
| Port | `6379` |

The setup script verifies connectivity by running `redis-cli ping` and expecting a `PONG` response.

```bash
# Connect to Redis
redis-cli
```

## Managing services

Use `brew services` to control both services:

```bash
# Check status of all Homebrew-managed services
brew services list

# Start, stop, or restart PostgreSQL
brew services start postgresql@17
brew services stop postgresql@17
brew services restart postgresql@17

# Start, stop, or restart Redis
brew services start redis
brew services stop redis
brew services restart redis
```

## GUI tools

The Brewfile installs three macOS casks for database management:

| Application | Purpose |
|-------------|---------|
| Beekeeper Studio | General-purpose SQL client |
| pgAdmin4 | PostgreSQL administration and query tool |
| Redis Insight | Redis GUI for browsing keys, running commands, and monitoring |

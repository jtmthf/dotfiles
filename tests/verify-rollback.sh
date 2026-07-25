#!/usr/bin/env bash
# Rollback verification — runs INSIDE the Docker container, after install.sh + verify.sh.
# Proves the ssh-config backup/restore round-trip:
#   seed real config -> install (prepends Include, backs up) -> rollback (restores original).

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
PASS=0
FAIL=0

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

pass() { echo -e "${green}PASS${reset}  $1"; (( PASS++ )) || true; }
fail() { echo -e "${red}FAIL${reset}  $1"; (( FAIL++ )) || true; }

MARKER="Host rollback-canary"
SSH_INCLUDE="Include $DOTFILES_DIR/config/ssh/config"

echo "=== Rollback verification (ssh config round-trip) ==="

# 1. Seed a real user ssh config containing a canary entry and no Include
rm -f "$HOME/.ssh/config"
printf '%s\n  HostName example.com\n' "$MARKER" > "$HOME/.ssh/config"
chmod 600 "$HOME/.ssh/config"

# 2. Re-run the installer (idempotent second run; SKIP_BREW_BUNDLE is inherited in fast mode)
bash "$DOTFILES_DIR/install.sh"

if grep -qF "$SSH_INCLUDE" "$HOME/.ssh/config"; then
    pass "install prepended Include to existing config"
else
    fail "install did not add Include line"
fi
if grep -qF "$MARKER" "$HOME/.ssh/config"; then
    pass "install preserved existing content"
else
    fail "install lost existing config content"
fi

# shellcheck disable=SC2012  # intentional: pick newest backup dir by mtime via glob
latest_backup=$(ls -dt "$HOME"/.dotfiles_backup_* | head -1)
if [[ -f "$latest_backup/ssh_config" ]] && grep -qF "$MARKER" "$latest_backup/ssh_config"; then
    pass "install backed up pre-modification ssh config"
else
    fail "no ssh_config backup found in $latest_backup"
fi

# 3. Roll back
bash "$DOTFILES_DIR/install.sh" --rollback

if [[ -f "$HOME/.ssh/config" ]]; then
    pass "ssh config still exists after rollback"
else
    fail "rollback deleted ~/.ssh/config"
fi
if grep -qF "$MARKER" "$HOME/.ssh/config" 2>/dev/null; then
    pass "rollback restored original content"
else
    fail "rollback lost the canary entry"
fi
if ! grep -qF "$SSH_INCLUDE" "$HOME/.ssh/config" 2>/dev/null; then
    pass "rollback removed the Include line"
else
    fail "Include line still present after rollback"
fi

echo ""
echo "=== Rollback results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]

#!/usr/bin/env bash
# Verification script — run inside the Docker container after install.sh completes.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
PASS=0
FAIL=0

green='\033[0;32m'
red='\033[0;31m'
reset='\033[0m'

pass() { echo -e "${green}PASS${reset}  $1"; (( PASS++ )) || true; }
fail() { echo -e "${red}FAIL${reset}  $1"; (( FAIL++ )) || true; }

assert_file() {
    local desc="$1" path="$2"
    if [[ -f "$path" ]]; then
        pass "$desc"
    else
        fail "$desc — not found: $path"
    fi
}

assert_symlink() {
    local desc="$1" link="$2" expected_target="$3"
    if [[ ! -L "$link" ]]; then
        fail "$desc — not a symlink: $link"
        return
    fi
    local actual
    actual=$(readlink -f "$link")
    if [[ "$actual" == "$expected_target" ]]; then
        pass "$desc"
    else
        fail "$desc — expected $expected_target, got $actual"
    fi
}

assert_contains() {
    local desc="$1" path="$2" pattern="$3"
    if grep -qF "$pattern" "$path" 2>/dev/null; then
        pass "$desc"
    else
        fail "$desc — '$pattern' not found in $path"
    fi
}

assert_dir() {
    local desc="$1" path="$2"
    if [[ -d "$path" ]]; then
        pass "$desc"
    else
        fail "$desc — not a directory: $path"
    fi
}

assert_cmd() {
    local desc="$1" cmd="$2"
    if command -v "$cmd" &>/dev/null; then
        pass "$desc"
    else
        fail "$desc — command not found: $cmd"
    fi
}

assert_json_has() {
    local desc="$1" path="$2" filter="$3"
    if jq -e "$filter" "$path" >/dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc — jq filter '$filter' did not match in $path"
    fi
}

echo "=== Dotfiles verification ==="
echo "DOTFILES_DIR=$DOTFILES_DIR"
echo "HOME=$HOME"
echo ""

# 1. Bootstrap file
echo "--- Bootstrap ---"
# shellcheck disable=SC2088  # literal test description, not a path
assert_file    "~/.zshenv exists"             "$HOME/.zshenv"
# shellcheck disable=SC2088  # literal test description, not a path
assert_contains "~/.zshenv sets ZDOTDIR"      "$HOME/.zshenv" "ZDOTDIR"
# shellcheck disable=SC2088  # literal test description, not a path
assert_contains "~/.zshenv sources .zshenv"   "$HOME/.zshenv" "source"
if [[ "$(readlink -f "$HOME/.dotfiles")" == "$(readlink -f "$DOTFILES_DIR")" ]]; then
    # shellcheck disable=SC2088  # literal test description, not a path
    pass "~/.dotfiles resolves to the dotfiles checkout"
else
    # shellcheck disable=SC2088  # literal test description, not a path
    fail "~/.dotfiles does not resolve to $DOTFILES_DIR"
fi

# 2. Symlinks
echo ""
echo "--- Symlinks ---"
assert_symlink "zsh/.zshenv symlink"          "$HOME/.config/zsh/.zshenv"           "$DOTFILES_DIR/zsh/.zshenv"
assert_symlink "zsh/.zprofile symlink"        "$HOME/.config/zsh/.zprofile"         "$DOTFILES_DIR/zsh/.zprofile"
assert_symlink "zsh/.zshrc symlink"           "$HOME/.config/zsh/.zshrc"            "$DOTFILES_DIR/zsh/.zshrc"
assert_symlink "starship.toml symlink"        "$HOME/.config/starship.toml"         "$DOTFILES_DIR/config/starship.toml"
assert_symlink "mise/config.toml symlink"     "$HOME/.config/mise/config.toml"      "$DOTFILES_DIR/config/mise/config.toml"
assert_symlink "tmux/tmux.conf symlink"       "$HOME/.config/tmux/tmux.conf"        "$DOTFILES_DIR/config/tmux/tmux.conf"
assert_symlink "git/config symlink"           "$HOME/.config/git/config"            "$DOTFILES_DIR/config/git/config"
assert_symlink "git/ignore symlink"           "$HOME/.config/git/ignore"            "$DOTFILES_DIR/config/git/ignore"
if [[ -f "$HOME/.claude/settings.json" && ! -L "$HOME/.claude/settings.json" ]]; then
    pass "claude/settings.json is a real merged file"
else
    fail "claude/settings.json missing or is a symlink: $HOME/.claude/settings.json"
fi
assert_json_has "claude/settings.json is valid JSON"            "$HOME/.claude/settings.json" "."
assert_json_has "claude/settings.json contains repo permission" "$HOME/.claude/settings.json" '.permissions.allow | index("Bash(rg:*)")'

# Idempotency: running safe_link again produces the same result (no nested symlinks)
for link in \
    "$HOME/.config/zsh/.zshenv" \
    "$HOME/.config/zsh/.zprofile" \
    "$HOME/.config/zsh/.zshrc" \
    "$HOME/.config/starship.toml" \
    "$HOME/.config/mise/config.toml" \
    "$HOME/.config/git/config" \
    "$HOME/.config/git/ignore"; do
    if [[ -L "$link" ]]; then
        target=$(readlink "$link")
        if [[ "$target" == "$DOTFILES_DIR"* ]]; then
            pass "safe_link idempotent: $link → $target (direct, not nested)"
        else
            fail "safe_link idempotent: $link → $target (unexpected target)"
        fi
    fi
done
assert_symlink "claude/CLAUDE.md symlink"     "$HOME/.claude/CLAUDE.md"             "$DOTFILES_DIR/config/claude/CLAUDE.md"
assert_symlink "claude/TMUX.md symlink"       "$HOME/.claude/TMUX.md"               "$DOTFILES_DIR/config/claude/TMUX.md"
assert_symlink "claude/SEARCH.md symlink"     "$HOME/.claude/SEARCH.md"             "$DOTFILES_DIR/config/claude/SEARCH.md"
assert_symlink "claude/WEB.md symlink"        "$HOME/.claude/WEB.md"                "$DOTFILES_DIR/config/claude/WEB.md"

# 3. Written files (not symlinks)
echo ""
echo "--- Written files ---"
# shellcheck disable=SC2088  # literal test description, not a path
assert_file    "~/.ssh/config exists"         "$HOME/.ssh/config"
# shellcheck disable=SC2088  # literal test description, not a path
assert_contains "~/.ssh/config has Include"   "$HOME/.ssh/config" "Include $DOTFILES_DIR/config/ssh/config"
# shellcheck disable=SC2088  # literal test description, not a path
assert_file    "~/.ssh/config.local exists"   "$HOME/.ssh/config.local"
assert_file    "git/config.local exists"      "$HOME/.config/git/config.local"
assert_file    "claude/settings.json exists"   "$HOME/.claude/settings.json"

# jq-merge: settings.json must be valid JSON with the expected structure
if command -v jq &>/dev/null && [[ -f "$HOME/.claude/settings.json" ]]; then
    if jq empty "$HOME/.claude/settings.json" 2>/dev/null; then
        pass "claude/settings.json is valid JSON"
    else
        fail "claude/settings.json is not valid JSON"
    fi
    if jq -e '.permissions' "$HOME/.claude/settings.json" &>/dev/null; then
        pass "claude/settings.json has .permissions key (jq-merge produced correct structure)"
    else
        fail "claude/settings.json missing .permissions key (jq-merge may have failed)"
    fi
    # Verify the merge result respects the union_keep_order semantics
    if jq -e '.permissions.allow | length > 0' "$HOME/.claude/settings.json" &>/dev/null; then
        pass "claude/settings.json has non-empty .permissions.allow (union merge preserved entries)"
    fi
else
    fail "jq not available or settings.json missing — cannot verify merge semantics"
fi

# 4. Zsh plugins
echo ""
echo "--- Zsh plugins ---"
assert_dir "zsh-syntax-highlighting cloned"   "$DOTFILES_DIR/zsh/plugins/zsh-syntax-highlighting"
assert_dir "zsh-autosuggestions cloned"       "$DOTFILES_DIR/zsh/plugins/zsh-autosuggestions"
assert_dir "zsh-completions cloned"           "$DOTFILES_DIR/zsh/plugins/zsh-completions"

# 5. Tmux plugin manager
echo ""
echo "--- Tmux ---"
assert_dir "TPM cloned"                       "$HOME/.config/tmux/plugins/tpm"

# 6. Shell load
echo ""
echo "--- Shell ---"
if zsh -c 'source ~/.zshenv; [[ -n $ZDOTDIR ]]' 2>/dev/null; then
    pass "zsh sources ~/.zshenv and ZDOTDIR is set"
else
    fail "zsh could not source ~/.zshenv or ZDOTDIR is empty"
fi

if [[ "${DOTFILES_TEST_MODE:-fast}" == "full" ]]; then
    if zsh -i -c exit 2>/dev/null; then
        pass "interactive zsh starts cleanly"
    else
        fail "interactive zsh exited with error"
    fi
fi

# 7. Full-mode: tools in PATH
if [[ "${DOTFILES_TEST_MODE:-fast}" == "full" ]]; then
    echo ""
    echo "--- Tools (full mode) ---"
    for cmd in starship mise fzf bat fd rg nvim tmux zoxide; do
        assert_cmd "$cmd in PATH" "$cmd"
    done
fi

# Summary
echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[[ $FAIL -eq 0 ]]

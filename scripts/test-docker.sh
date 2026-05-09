#!/usr/bin/env bash
set -euo pipefail

MODE="${DOTFILES_TEST_MODE:-fast}"
TAG="dotfiles-test:$(git rev-parse --short HEAD 2>/dev/null || echo local)"

echo "Building image: $TAG (mode=$MODE)"
docker build -f tests/Dockerfile -t "$TAG" "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

SKIP_BREW_BUNDLE=""
[[ "$MODE" == "fast" ]] && SKIP_BREW_BUNDLE=1

docker run --rm \
    -e DOTFILES_TEST_MODE="$MODE" \
    -e SKIP_BREW_BUNDLE="$SKIP_BREW_BUNDLE" \
    "$TAG"

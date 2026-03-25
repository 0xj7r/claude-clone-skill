#!/bin/bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${HOME}/.claude/commands"

mkdir -p "$TARGET_DIR"

cp "$REPO_DIR/commands/clone.md" "$TARGET_DIR/clone.md"
cp "$REPO_DIR/commands/clone-setup.sh" "$TARGET_DIR/clone-setup.sh"
cp "$REPO_DIR/commands/extract-css.sh" "$TARGET_DIR/extract-css.sh"
cp "$REPO_DIR/commands/smart-strip.sh" "$TARGET_DIR/smart-strip.sh"

chmod +x "$TARGET_DIR/clone-setup.sh"
chmod +x "$TARGET_DIR/extract-css.sh"
chmod +x "$TARGET_DIR/smart-strip.sh"

echo "Installed Claude clone skill to $TARGET_DIR"

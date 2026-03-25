#!/bin/bash
# Clone setup — runs BEFORE Claude touches anything
# Usage: bash ~/.claude/commands/clone-setup.sh <URL> [project-name] [--skip-scaffold]

set -euo pipefail

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "Usage: clone-setup.sh <URL> [project-name] [--skip-scaffold]"
  exit 1
fi

PROJECT_NAME=""
SKIP_SCAFFOLD=0

shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-scaffold)
      SKIP_SCAFFOLD=1
      ;;
    *)
      if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME="$1"
      else
        echo "Unexpected argument: $1"
        echo "Usage: clone-setup.sh <URL> [project-name] [--skip-scaffold]"
        exit 1
      fi
      ;;
  esac
  shift
done

if [ -z "$PROJECT_NAME" ]; then
  PROJECT_SLUG="$(printf '%s' "$URL" | sed -E 's#https?://##; s#^www\.##; s#[/?#].*$##; s#[^A-Za-z0-9]+#-#g; s#-+#-#g; s#(^-|-$)##g' | tr '[:upper:]' '[:lower:]')"
  PROJECT_NAME="proj-${PROJECT_SLUG:-site}"
fi

PROJ_DIR="$HOME/$PROJECT_NAME"

echo "=== Clone Setup ==="
echo "URL: $URL"
echo "Project: $PROJ_DIR"
if [ "$SKIP_SCAFFOLD" -eq 1 ]; then
  echo "Scaffold: skip existing Next.js project"
fi
echo ""

# Phase 1: Scrape
echo "--- Validating prerequisites ---"
npx firecrawl-cli --version >/dev/null

echo ""
echo "--- Fetching source artifacts ---"
mkdir -p "$PROJ_DIR/fetched" "$PROJ_DIR/review"
printf '%s\n' "$URL" > "$PROJ_DIR/fetched/source-url.txt"

npx firecrawl-cli scrape "$URL" --format rawHtml -o "$PROJ_DIR/fetched/raw.html" &
RAW_PID=$!
npx firecrawl-cli scrape "$URL" --format branding --pretty -o "$PROJ_DIR/fetched/branding.json" &
BRANDING_PID=$!
npx firecrawl-cli scrape "$URL" --screenshot --pretty -o "$PROJ_DIR/fetched/screenshot.json" &
SCREENSHOT_PID=$!

wait "$RAW_PID"
wait "$BRANDING_PID"
wait "$SCREENSHOT_PID"

RAW_SIZE=$(wc -c < "$PROJ_DIR/fetched/raw.html")
RAW_TOKENS=$((RAW_SIZE / 4))
echo "Raw HTML: $RAW_SIZE bytes (~$RAW_TOKENS tokens)"

echo ""
echo "--- Creating lookup artifacts ---"
bash "$HOME/.claude/commands/smart-strip.sh" "$PROJ_DIR/fetched/raw.html" "$PROJ_DIR/fetched/blueprint.html"

if bash "$HOME/.claude/commands/extract-css.sh" \
  "$PROJ_DIR/fetched/raw.html" \
  "$PROJ_DIR/fetched/external.css" \
  "$URL"; then
  echo "External CSS extracted"
else
  echo "WARNING: External CSS extraction failed; continuing with raw HTML only"
fi

if [ "$RAW_SIZE" -gt 4000000 ]; then
  echo "WARNING: HTML is very large (>4MB). Prefer blueprint.html for navigation, but keep raw.html as the primary spec."
fi

if [ "$SKIP_SCAFFOLD" -eq 0 ]; then
  echo ""
  echo "--- Scaffolding Next.js ---"
  cd "$PROJ_DIR"
  yes "" | npx create-next-app@latest proj --typescript --tailwind --eslint --app --src-dir --use-npm
  mkdir -p "$PROJ_DIR/proj/src/components"
else
  if [ ! -d "$PROJ_DIR/proj" ]; then
    echo "ERROR: --skip-scaffold was provided but $PROJ_DIR/proj does not exist"
    exit 1
  fi
fi

echo ""
echo "=== Setup complete ==="
echo "Project dir: $PROJ_DIR"
echo "Raw HTML: $PROJ_DIR/fetched/raw.html ($RAW_TOKENS tokens)"
echo "Blueprint HTML: $PROJ_DIR/fetched/blueprint.html"
echo "External CSS: $PROJ_DIR/fetched/external.css"
echo "Branding JSON: $PROJ_DIR/fetched/branding.json"
echo "Screenshot JSON: $PROJ_DIR/fetched/screenshot.json"
echo "Next.js app: $PROJ_DIR/proj"
echo ""
echo "Ready for Claude to translate."

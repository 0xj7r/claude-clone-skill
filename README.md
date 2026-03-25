# Claude Clone Skill

A slash-command style website cloning workflow for Claude Code / Claude Desktop command setups.

This package keeps the cloning pipeline in one shared context while strengthening the inputs:

- full raw HTML
- stripped blueprint HTML for navigation
- external CSS extraction
- branding metadata
- screenshot metadata
- optional screenshot QA loop

## Files

- `commands/clone.md`
- `commands/clone-setup.sh`
- `commands/extract-css.sh`
- `commands/smart-strip.sh`

## Install

Copy the files into your Claude commands directory:

```bash
mkdir -p ~/.claude/commands
cp commands/clone.md ~/.claude/commands/clone.md
cp commands/clone-setup.sh ~/.claude/commands/clone-setup.sh
cp commands/extract-css.sh ~/.claude/commands/extract-css.sh
cp commands/smart-strip.sh ~/.claude/commands/smart-strip.sh
chmod +x ~/.claude/commands/clone-setup.sh
chmod +x ~/.claude/commands/extract-css.sh
chmod +x ~/.claude/commands/smart-strip.sh
```

## Dependencies

- `npx`
- `firecrawl-cli`
- `create-next-app`
- Playwright support in your Claude environment for visual QA

If Firecrawl is not authenticated:

```bash
npx firecrawl-cli login --browser
```

## Usage

```text
/clone https://example.com
/clone https://example.com my-project --qa
/clone https://example.com my-project --skip-scaffold
/clone --from-existing ~/proj-example
```

## Design

The pipeline deliberately avoids splitting the page into isolated section-generation agents. The current approach keeps a single translator agent in full-page context and uses helper scripts to improve source fidelity instead of reducing shared context.

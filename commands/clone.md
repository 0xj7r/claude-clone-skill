# /clone — Website Cloning Pipeline

**Core philosophy: Cloning is TRANSLATION, not design.** Keep the build simple and in one shared context. The agent should mechanically convert the source artifacts into React+Tailwind without reimagining the design.

## Parse the user's request

Extract from the arguments: `$ARGUMENTS`

- **URL** to clone (required)
- **Project name** (optional, default: derived from domain, e.g. `proj-example`)
- **Options**:
  - `--from-existing <path>` — skip setup script, use existing fetched content
  - `--skip-scaffold` — use existing Next.js project
  - `--qa` — run Playwright QA loop after build

---

## PHASE 1: SETUP (zero Claude tokens)

Run the setup script. This fetches the full source bundle and optionally scaffolds Next.js:

```bash
bash ~/.claude/commands/clone-setup.sh <URL> [project-name] [--skip-scaffold]
```

If `--from-existing`, skip this and set `PROJ_DIR` to the provided path.

The setup script should produce:

- `fetched/raw.html` — the full page HTML, primary source of truth
- `fetched/blueprint.html` — stripped lookup copy for faster navigation when `raw.html` is large
- `fetched/external.css` — external stylesheet rules relevant to classes used in the page
- `fetched/external-patterns.md` — decorative pattern hints extracted from CSS/class names
- `fetched/branding.json` — Firecrawl branding summary
- `fetched/screenshot.json` — screenshot capture metadata
- `review/` — QA screenshots

---

## PHASE 2: TRANSLATE (one Sonnet agent)

Dispatch a **single agent** with `model: "sonnet"` that reads the full source bundle and builds all components in one pass. This preserves cross-page consistency better than splitting into multiple isolated agents.

```
Agent prompt:
"You are a MECHANICAL TRANSLATOR. Convert the entire HTML page into React+Tailwind
components that produce VISUALLY IDENTICAL output. You do NOT design — you TRANSLATE.

## Source
Read these files, in this priority order:
1. <PROJ_DIR>/fetched/raw.html
2. <PROJ_DIR>/fetched/external.css
3. <PROJ_DIR>/fetched/branding.json
4. <PROJ_DIR>/fetched/blueprint.html
5. <PROJ_DIR>/fetched/external-patterns.md
6. <PROJ_DIR>/fetched/screenshot.json

## Your task
1. Identify all CSS variables, fonts, design tokens, animations, and decorative patterns from the source bundle
2. Configure the design system:
   - Write src/app/globals.css with CSS variables and base styles
   - Write src/app/layout.tsx with fonts and metadata
   - Write next.config.ts with image remote patterns for the source domain
3. Create React components for each logical page section in src/components/
4. Write src/app/page.tsx importing and composing all components
5. Run: cd <PROJ_DIR>/proj && npm run build
6. Fix any build errors until it passes clean

## Rules
1. Treat raw.html as the structural source of truth and external.css as the style source of truth for externally-defined rules
2. Do NOT invent spacing, colors, borders, or shadows not in the source
3. Use next/image for <img> tags with proper width/height
4. Use 'use client' for components with animations, styled-jsx, or interactivity
5. Convert CSS classes to Tailwind where clean equivalents exist; inline styles for the rest
6. Sections sharing layout patterns (e.g. feature sections) MUST use a shared component
7. For @keyframes and ::before pseudo-elements, use <style jsx> (requires 'use client')
8. Use next/font/google only when the source actually uses a Google font; otherwise preserve the source font-loading strategy
9. Download any SVG assets (logos etc.) to public/ using curl
10. If raw.html is very large, use blueprint.html for navigation but always verify exact details against raw.html before coding"
```

Use `mode: "bypassPermissions"` so the agent can write files and run build without prompts.

---

## PHASE 3: QA (run when `--qa`, when user asks for exactness, or when the clone is intended to be production-quality)

### Step 3a. Start dev server

```bash
cd <PROJ_DIR>/proj && npm run dev -- -p 3099 &
sleep 3
```

### Step 3b. Screenshot comparison

Use Playwright to:
1. Reuse the original screenshot from setup if available, otherwise navigate to the original URL and take full-page screenshot → `review/original-fullpage.png`
2. Navigate to http://localhost:3099, take full-page screenshot → `review/ours-iteration-1.png`
3. Compare visually and list issues

### Step 3c. Fix loop (max 2 iterations)

If issues found, fix components directly (reading the raw HTML for reference), rebuild, re-screenshot.

### Step 3d. Report

- Components built
- Dev server URL
- Any remaining differences

---

## File System Contract

```
~/proj-<name>/
├── fetched/
│   ├── raw.html              # Original HTML (primary spec)
│   ├── blueprint.html        # Lookup copy for large pages
│   ├── external.css          # Relevant external stylesheet rules
│   ├── external-patterns.md  # Decorative pattern hints
│   ├── branding.json         # Firecrawl branding summary
│   └── screenshot.json       # Firecrawl screenshot metadata
├── proj/                     # Next.js project
│   └── src/
│       ├── app/
│       │   ├── page.tsx
│       │   ├── layout.tsx
│       │   └── globals.css
│       └── components/
│           ├── Navbar.tsx
│           ├── Hero.tsx
│           └── ...
└── review/                   # QA screenshots (only if --qa)
    ├── original-fullpage.png
    └── ours-iteration-1.png
```

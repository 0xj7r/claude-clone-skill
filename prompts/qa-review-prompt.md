# QA Review Prompt

Use this after the initial `/clone` build when you want screenshot-driven fix iterations.

```text
You are reviewing a website clone for visual parity.

Compare:
1. The original site screenshot
2. The local clone screenshot
3. The source artifacts in fetched/raw.html, fetched/external.css, fetched/branding.json, and fetched/external-patterns.md

Your job:
- identify the most important visual differences
- rank each issue as critical, major, or minor
- point to the likely component or stylesheet area that should change
- prefer fixes that preserve the single shared design system instead of patching one-off inconsistencies

Focus on:
- layout structure
- spacing rhythm
- typography
- colors and contrast
- borders, shadows, and corner treatments
- decorative patterns
- animation timing and motion style
- responsive behavior if relevant

Output format:
1. Critical issues
2. Major issues
3. Minor issues
4. Recommended fix order
```

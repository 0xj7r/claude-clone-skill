#!/bin/bash
# Smart-strip HTML: removes bloat while preserving CSS classes, structure, and content
# Usage: smart-strip.sh <input.html> [output.html]
# If output not specified, writes to <input>-blueprint.html

INPUT="$1"
OUTPUT="${2:-${INPUT%.html}-blueprint.html}"

if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
  echo "Usage: smart-strip.sh <input.html> [output.html]"
  exit 1
fi

python3 << PYEOF
import re, sys

with open("$INPUT", 'r') as f:
    html = f.read()

original = len(html)
print(f"Original: {original:,} chars ({original//4:,} est tokens)")

# Remove script and style CONTENT
html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL)
html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL)

# Compress SVGs: keep tag attrs, remove path data
html = re.sub(r'(<svg[^>]*>).*?(</svg>)', r'\1[...]</svg>', html, flags=re.DOTALL)

# Remove noscript and comments
html = re.sub(r'<noscript[^>]*>.*?</noscript>', '', html, flags=re.DOTALL)
html = re.sub(r'<!--.*?-->', '', html, flags=re.DOTALL)

# Remove tracking/framework attributes
html = re.sub(r'\s+data-wf-[a-z-]+="[^"]*"', '', html)
html = re.sub(r'\s+data-w-id="[^"]*"', '', html)
html = re.sub(r'\s+data-framer-[a-z-]+="[^"]*"', '', html)

# Remove responsive image bloat
html = re.sub(r'srcset="([^"\s]+)\s[^"]*"', r'srcset="\1"', html)
html = re.sub(r'\s+sizes="[^"]*"', '', html)
html = re.sub(r'\s+loading="[^"]*"', '', html)
html = re.sub(r'\s+decoding="[^"]*"', '', html)

# Collapse whitespace
html = re.sub(r'\n\s*\n\s*\n', '\n\n', html)
html = re.sub(r'  +', ' ', html)
html = re.sub(r'<(div|span)\s*>\s*</\1>', '', html)

stripped = len(html)
pct = round((1 - stripped/original) * 100)
print(f"Stripped:  {stripped:,} chars ({stripped//4:,} est tokens) — {pct}% reduction")

with open("$OUTPUT", 'w') as f:
    f.write(html)
print(f"Saved to: $OUTPUT")
PYEOF

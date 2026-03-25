#!/bin/bash
# extract-css.sh — Extract stylesheet rules for classes used in an HTML file
# Usage: bash extract-css.sh <html-file> <output.css> [source-url]
#
# 1. Finds all external stylesheet URLs in the HTML
# 2. Downloads them
# 3. Extracts all class names used in the HTML
# 4. Filters CSS rules to only those matching used classes
# 5. Outputs a clean CSS file with just the relevant rules + decorative pattern summary

set -euo pipefail

BLUEPRINT="${1:?Usage: extract-css.sh <html-file> <output.css> [source-url]}"
OUTPUT="${2:?Usage: extract-css.sh <html-file> <output.css> [source-url]}"
SOURCE_URL="${3:-}"
TMPDIR=$(mktemp -d)

trap "rm -rf $TMPDIR" EXIT

echo "=== CSS Extraction ==="

# Step 1: Extract stylesheet URLs from the HTML
echo "1. Finding stylesheets..."
grep -oE "href=[\"'][^\"']+\.css[^\"']*[\"']" "$BLUEPRINT" | \
  sed -E "s/^href=[\"']|[\"']$//g" | \
  sort -u > "$TMPDIR/css_urls.txt"

CSS_COUNT=$(wc -l < "$TMPDIR/css_urls.txt" | tr -d ' ')
echo "   Found $CSS_COUNT stylesheet(s)"

if [ "$CSS_COUNT" -eq 0 ]; then
  echo "   No external stylesheets found — site likely uses Tailwind (classes are self-documenting in blueprint)."
  echo "/* No external stylesheets — CSS classes are inline in blueprint HTML */" > "$OUTPUT"
  PATTERNS_FILE="${OUTPUT%.css}-patterns.md"
  cat > "$PATTERNS_FILE" <<'EOF'
# Decorative Patterns Detected

No external stylesheets were found.
Check raw HTML and inline styles for decorative patterns, animations, and pseudo-elements.
EOF
  exit 0
fi

# Step 2: Download all stylesheets
echo "2. Downloading stylesheets..."
> "$TMPDIR/all.css"
while read -r url; do
  if [[ "$url" == //* ]]; then
    url="https:$url"
  elif [[ "$url" == /* ]]; then
    if [ -n "$SOURCE_URL" ]; then
      BASE="$(python3 - <<'PYEOF' "$SOURCE_URL"
import sys
from urllib.parse import urlsplit

parts = urlsplit(sys.argv[1])
print(f"{parts.scheme}://{parts.netloc}")
PYEOF
)"
      url="${BASE}${url}"
    fi
  elif [[ "$url" != http://* && "$url" != https://* ]]; then
    if [ -n "$SOURCE_URL" ]; then
      url="$(python3 - <<'PYEOF' "$SOURCE_URL" "$url"
import sys
from urllib.parse import urljoin

print(urljoin(sys.argv[1], sys.argv[2]))
PYEOF
)"
    fi
  fi
  echo "   Fetching: ${url:0:80}..."
  curl -sL "$url" >> "$TMPDIR/all.css" 2>/dev/null || echo "   Warning: Failed to fetch $url"
  echo "" >> "$TMPDIR/all.css"
done < "$TMPDIR/css_urls.txt"

ALL_SIZE=$(wc -c < "$TMPDIR/all.css" | tr -d ' ')
echo "   Total CSS: ${ALL_SIZE} bytes"

# Step 3: Extract all class names from the blueprint HTML
echo "3. Extracting class names from blueprint..."
grep -oE 'class="[^"]*"' "$BLUEPRINT" | \
  sed 's/class="//;s/"//' | \
  tr ' ' '\n' | \
  grep -v '^$' | \
  sort -u > "$TMPDIR/used_classes.txt"

CLASS_COUNT=$(wc -l < "$TMPDIR/used_classes.txt" | tr -d ' ')
echo "   Found $CLASS_COUNT unique classes"

# Step 4: Filter CSS rules using Python (write script to file first)
echo "4. Extracting relevant CSS rules..."

cat > "$TMPDIR/filter_css.py" << 'PYEOF'
import sys
import re
import os

tmpdir = sys.argv[1]

css_file = os.path.join(tmpdir, "all.css")
classes_file = os.path.join(tmpdir, "used_classes.txt")
filtered_file = os.path.join(tmpdir, "filtered.css")
patterns_file = os.path.join(tmpdir, "patterns.md")

# Read used classes
with open(classes_file) as f:
    used_classes = set(line.strip() for line in f if line.strip())

# Read CSS
with open(css_file) as f:
    css_text = f.read()

# Remove comments
css_text = re.sub(r'/\*.*?\*/', '', css_text, flags=re.DOTALL)

# Parse CSS into rules
rules = []
depth = 0
current_rule = ""
in_media = False
media_prefix = ""

i = 0
while i < len(css_text):
    c = css_text[i]
    if c == '@' and depth == 0 and not in_media:
        end = css_text.find('{', i)
        if end != -1:
            at_rule = css_text[i:end].strip()
            if '@media' in at_rule or '@supports' in at_rule:
                in_media = True
                media_prefix = at_rule
                depth = 0
                i = end + 1
                continue
            elif '@keyframes' in at_rule or '@font-face' in at_rule:
                brace_depth = 1
                j = end + 1
                while j < len(css_text) and brace_depth > 0:
                    if css_text[j] == '{': brace_depth += 1
                    elif css_text[j] == '}': brace_depth -= 1
                    j += 1
                rules.append(("", css_text[i:j].strip()))
                i = j
                continue

    if c == '{':
        depth += 1
        current_rule += c
    elif c == '}':
        depth -= 1
        current_rule += c
        if depth == 0:
            if in_media:
                if current_rule.strip():
                    rules.append((media_prefix, current_rule.strip()))
                current_rule = ""
            else:
                if current_rule.strip():
                    rules.append(("", current_rule.strip()))
                current_rule = ""
        elif depth < 0:
            in_media = False
            media_prefix = ""
            depth = 0
            current_rule = ""
    else:
        current_rule += c
    i += 1

# Filter rules to those matching used classes
filtered = []
for media, rule in rules:
    brace_idx = rule.find('{')
    if brace_idx == -1:
        continue
    selector = rule[:brace_idx].strip()

    if selector.startswith('@font-face') or selector.startswith('@keyframes'):
        filtered.append(rule)
        continue

    matched = False
    for cls in used_classes:
        if f'.{cls}' in selector:
            pattern = re.escape(f'.{cls}')
            if re.search(pattern + r'(?=[\s,.:{>\[+~)\]]|$)', selector):
                matched = True
                break

    if matched:
        props = rule[brace_idx+1:rule.rfind('}')].strip()
        prop_list = [p.strip() for p in props.split(';') if p.strip()]
        formatted_props = ';\n  '.join(prop_list)
        if media:
            filtered.append(f"{media} {{\n  {selector} {{\n    {formatted_props};\n  }}\n}}")
        else:
            filtered.append(f"{selector} {{\n  {formatted_props};\n}}")

with open(filtered_file, 'w') as f:
    f.write(f"/* Extracted CSS: {len(filtered)} rules matching {len(used_classes)} blueprint classes */\n\n")
    f.write('\n\n'.join(filtered))

print(f"   Matched {len(filtered)} CSS rules")

# Step 5: Detect decorative patterns
patterns = []

full_css = '\n'.join(r[1] for r in rules if any(f'.{c}' in r[1] for c in used_classes if len(c) > 2))

if any(c for c in used_classes if 'plus' in c or 'cross' in c or 'grid-marker' in c):
    patterns.append("CROSSHAIR/PLUS MARKERS: Site uses SVG crosshair markers at grid intersections. Look for plus-grid, plus-svg classes. These are typically absolute-positioned SVG elements at section corners.")

border_classes = [c for c in used_classes if 'border' in c.lower()]
if border_classes:
    patterns.append(f"GRID BORDERS: {len(border_classes)} border-related classes: {', '.join(border_classes[:10])}. These create structured grid lines between sections/columns.")

if any(c for c in used_classes if 'dot' in c or 'grain' in c or 'noise' in c or 'pattern' in c):
    patterns.append("TEXTURE PATTERNS: Dot/grain/noise patterns detected as decorative backgrounds.")

if any(c for c in used_classes if 'hide' in c.lower()):
    hide_classes = [c for c in used_classes if 'hide' in c.lower()]
    patterns.append(f"RESPONSIVE VISIBILITY: {len(hide_classes)} responsive hide classes: {', '.join(hide_classes[:5])}.")

if any(c for c in used_classes if 'wrapper' in c.lower() and ('border' in c.lower() or 'line' in c.lower())):
    patterns.append("DECORATIVE BORDERS: Border wrapper elements detected — likely corner marks, divider lines, or section framing.")

corner_classes = [c for c in used_classes if any(x in c.lower() for x in ['corner', 'top-left', 'top-right', 'bottom-left', 'bottom-right'])]
if corner_classes:
    patterns.append(f"CORNER DECORATIONS: {len(corner_classes)} corner-positioned classes: {', '.join(corner_classes[:8])}. These create decorative corner marks or borders.")

with open(patterns_file, 'w') as f:
    f.write("# Decorative Patterns Detected\n\n")
    f.write("IMPORTANT: These patterns MUST be implemented in the clone. They are part of the site's visual identity.\n\n")
    if patterns:
        for p in patterns:
            name, desc = p.split(':', 1)
            f.write(f"## {name.strip()}\n{desc.strip()}\n\n")
    else:
        f.write("No specific decorative patterns detected from class names.\nCheck the blueprint HTML for inline-style decorative elements.\n")

print(f"   Detected {len(patterns)} decorative pattern(s)")
PYEOF

python3 "$TMPDIR/filter_css.py" "$TMPDIR"

# Copy outputs
cp "$TMPDIR/filtered.css" "$OUTPUT"

PATTERNS_FILE="${OUTPUT%.css}-patterns.md"
if [ -f "$TMPDIR/patterns.md" ]; then
  cp "$TMPDIR/patterns.md" "$PATTERNS_FILE"
  echo ""
  echo "=== Decorative Patterns ==="
  cat "$PATTERNS_FILE"
fi

OUTPUT_SIZE=$(wc -c < "$OUTPUT" | tr -d ' ')
OUTPUT_TOKENS=$((OUTPUT_SIZE / 4))
echo ""
echo "=== Done ==="
echo "CSS output: $OUTPUT (${OUTPUT_SIZE} chars, ~${OUTPUT_TOKENS} est tokens)"
echo "Patterns:   $PATTERNS_FILE"

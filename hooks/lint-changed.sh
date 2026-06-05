#!/usr/bin/env bash
# Rubocop on the just-edited Ruby file.
# Fires after every Edit/Write. Filters to *.rb internally.
# Best-effort: silently skips if the project doesn't have rubocop installed.

set -u

# Claude Code delivers the PostToolUse payload as JSON on stdin; the edited
# path lives at .tool_input.file_path. (There is no CLAUDE_FILE env var.)
input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -z "$file" ] && file="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

case "$file" in
  *.rb) ;;
  *) exit 0 ;;
esac

project_root="$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$project_root" ] && exit 0

# Only run if the project has rubocop bundled.
if [ ! -f "$project_root/Gemfile.lock" ] || ! grep -q "^\s*rubocop" "$project_root/Gemfile.lock" 2>/dev/null; then
  exit 0
fi

# Run rubocop on the single file. Print only error/warning lines, keep it short.
cd "$project_root" 2>/dev/null || exit 0

output="$(bundle exec rubocop --no-color --format simple "$file" 2>&1 || true)"

# If clean (no offenses), don't print anything — silence is golden.
if echo "$output" | grep -qE "no offenses detected|0 offenses"; then
  exit 0
fi

# If offenses, print a tight summary so Claude can react.
echo "Rubocop on $file:"
echo "$output" | head -20

exit 0

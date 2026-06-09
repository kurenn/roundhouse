#!/usr/bin/env bash
# TDD discipline reminder.
# Fires after every Edit/Write. Filters to production code under app/ internally.
# Prints a one-line nudge if no spec/test file has been touched in the working tree.
# Stateless, zero token cost — Claude reads stdout on its next turn.

set -u

# Claude Code delivers the PostToolUse payload as JSON on stdin; the edited
# path lives at .tool_input.file_path. (There is no CLAUDE_FILE env var.)
input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -z "$file" ] && file="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$file" ] && exit 0

# Only fire for production Ruby code under app/ (and lib/).
case "$file" in
  */app/models/*.rb|*/app/controllers/*.rb|*/app/services/*.rb|*/app/jobs/*.rb|*/app/mailers/*.rb|*/app/channels/*.rb|*/app/helpers/*.rb|*/lib/*.rb) ;;
  *) exit 0 ;;
esac

# If the edited file is itself a spec/test, skip the reminder.
case "$file" in
  *_spec.rb|*_test.rb) exit 0 ;;
esac

# Find the project root via git.
project_root="$(cd "$(dirname "$file")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)"
[ -z "$project_root" ] && exit 0

cd "$project_root" 2>/dev/null || exit 0

# If a spec/test has already been touched in the working tree, no nudge needed.
if git status --porcelain spec/ test/ 2>/dev/null | grep -qE '_spec\.rb|_test\.rb'; then
  exit 0
fi

echo "TDD reminder: production code under app/ was just edited but no spec/test file has changed in the working tree. If this task has user-visible behavior, write or update the spec before/alongside the production change."

exit 0

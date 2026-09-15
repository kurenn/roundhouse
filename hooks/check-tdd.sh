#!/usr/bin/env bash
# TDD discipline reminder.
# Fires after every Edit/Write. Filters to production code under app/ internally.
# Prints a one-line nudge if the edited file's own spec/test hasn't been touched.
# Stateless. Emits hookSpecificOutput.additionalContext so Claude actually sees it.

set -u

# Deliver a message to Claude.
# PostToolUse stdout at exit 0 goes to the debug log only — Claude never sees it.
# hookSpecificOutput.additionalContext is the documented channel that reaches the
# transcript. Without jq, fall back to exit 2, which shows stderr to Claude.
emit() {
  if command -v jq >/dev/null 2>&1; then
    # shellcheck disable=SC2016
    jq -nc --arg t "$1" \
      '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$t}}'
    exit 0
  fi
  printf '%s\n' "$1" >&2
  exit 2
}

# Claude Code delivers the PostToolUse payload as JSON on stdin; the edited
# path lives at .tool_input.file_path. (There is no CLAUDE_FILE env var.)
input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -z "$file" ] && file="$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -z "$file" ] && exit 0

# Only fire for production Ruby code under app/ (and lib/).
case "$file" in
  */app/*.rb|*/lib/*.rb) ;;
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

# If this file's own spec/test has already been touched, no nudge needed. The
# leading [ /] is the porcelain status field or a directory boundary, so
# blog_post_spec.rb doesn't answer for post.rb.
# ponytail: basename match, so two Post classes in different namespaces share a
# spec signal — map app/ -> spec/ paths if that collision ever bites.
base="$(basename "$file" .rb)"
if git status --porcelain 2>/dev/null | grep -qE "[ /]${base}_(spec|test)\.rb$"; then
  exit 0
fi

emit "TDD reminder: production code under app/ was just edited but ${base}_spec.rb has not changed in the working tree. If this task has user-visible behavior, write or update the spec before/alongside the production change."

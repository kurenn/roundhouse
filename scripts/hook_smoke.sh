#!/usr/bin/env bash
# Hook smoke test / benchmark.
# Pipes a representative PostToolUse JSON payload into each hook and checks
# that the hook delivers its reminder in a shape Claude actually receives.
#
# A hook that prints bare text and exits 0 is invisible: PostToolUse stdout at
# exit 0 goes to the debug log only. Delivery therefore means valid JSON on
# stdout carrying .hookSpecificOutput.additionalContext. Asserting "it printed
# something" is what let the invisible-hook regression ship.
#
# Usage: hook_smoke.sh <hooks_dir>
#
# Exit 0 if all behavioral hooks fire as expected, 1 otherwise.
# Prints a PASS/FAIL line per hook plus a summary count.

set -u

HOOKS_DIR="${1:?usage: hook_smoke.sh <hooks_dir>}"
HOOKS_DIR="$(cd "$HOOKS_DIR" && pwd)"

command -v jq >/dev/null 2>&1 || { echo "hook_smoke: jq is required to verify hook output shape"; exit 1; }

pass=0
fail=0

ok()   { echo "  PASS  $1"; pass=$((pass+1)); }
bad()  { echo "  FAIL  $1"; fail=$((fail+1)); }

# Build a throwaway git repo that looks like a Rails app so the hooks'
# git-based logic has something real to inspect.
sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
(
  cd "$sandbox" || exit 1
  git init -q
  git config user.email t@t.t
  git config user.name t
  mkdir -p app/models db/migrate spec/models
  echo "class Post < ApplicationRecord; end" > app/models/post.rb
  cat > db/migrate/20260101000000_risky.rb <<'RB'
class Risky < ActiveRecord::Migration[7.1]
  def change
    remove_column :posts, :legacy
    add_index :posts, :slug
    add_reference :posts, :author
    add_column :posts, :flag, :boolean, null: false
  end
end
RB
  git add -A && git commit -qm init
  # Stage an unspecced edit to app/ so check-tdd has reason to nudge.
  echo "# touched" >> app/models/post.rb
)

payload() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$1"; }

# Extract the text Claude would actually receive; empty if the hook emitted
# anything other than a well-formed additionalContext payload.
ctx() { printf '%s' "$1" | jq -er '.hookSpecificOutput.additionalContext' 2>/dev/null; }

echo "Hooks under test: $HOOKS_DIR"
echo

# --- check-migration.sh : expect production-risk warnings ---
out="$(payload "$sandbox/db/migrate/20260101000000_risky.rb" | bash "$HOOKS_DIR/check-migration.sh" 2>&1)"
got="$(ctx "$out")"
if printf '%s' "$got" | grep -q "Migration safety reminders:"; then
  ok "check-migration delivers warnings to Claude via additionalContext"
else
  bad "check-migration did not deliver additionalContext (got: ${out:-<empty>})"
fi

# --- check-tdd.sh : expect the TDD nudge (app/ edited, no spec touched) ---
out="$(payload "$sandbox/app/models/post.rb" | bash "$HOOKS_DIR/check-tdd.sh" 2>&1)"
got="$(ctx "$out")"
if printf '%s' "$got" | grep -q "TDD reminder:"; then
  ok "check-tdd delivers the reminder to Claude via additionalContext"
else
  bad "check-tdd did not deliver additionalContext (got: ${out:-<empty>})"
fi

# --- check-tdd.sh : a dirty spec for some *other* file must not silence it ---
# Staged, not just untracked: git collapses a wholly-untracked spec/ to "?? spec/",
# which would hide the path the old working-tree-wide grep was matching on.
echo "RSpec.describe Comment do; end" > "$sandbox/spec/models/comment_spec.rb"
git -C "$sandbox" add spec/models/comment_spec.rb
out="$(payload "$sandbox/app/models/post.rb" | bash "$HOOKS_DIR/check-tdd.sh" 2>&1)"
got="$(ctx "$out")"
if printf '%s' "$got" | grep -q "TDD reminder:"; then
  ok "check-tdd still nudges when only an unrelated spec is dirty"
else
  bad "check-tdd was silenced by an unrelated dirty spec (got: ${out:-<empty>})"
fi

# --- lint-changed.sh : no rubocop in sandbox, so it must exit cleanly/silently ---
out="$(payload "$sandbox/app/models/post.rb" | bash "$HOOKS_DIR/lint-changed.sh" 2>&1)"
rc=$?
if [ $rc -eq 0 ] && [ -z "$out" ]; then
  ok "lint-changed exits clean when project has no rubocop"
else
  bad "lint-changed misbehaved (rc=$rc out: ${out:-<empty>})"
fi

echo
echo "Summary: $pass passed, $fail failed"
[ $fail -eq 0 ]

#!/usr/bin/env bash
# Hook smoke test / benchmark.
# Pipes a representative PostToolUse JSON payload into each hook and checks
# whether the hook emits its expected reminder.
#
# Usage: hook_smoke.sh <hooks_dir>
#
# Exit 0 if all behavioral hooks fire as expected, 1 otherwise.
# Prints a PASS/FAIL line per hook plus a summary count.

set -u

HOOKS_DIR="${1:?usage: hook_smoke.sh <hooks_dir>}"
HOOKS_DIR="$(cd "$HOOKS_DIR" && pwd)"

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

echo "Hooks under test: $HOOKS_DIR"
echo

# --- check-migration.sh : expect production-risk warnings ---
out="$(payload "$sandbox/db/migrate/20260101000000_risky.rb" | bash "$HOOKS_DIR/check-migration.sh" 2>&1)"
if echo "$out" | grep -q "Migration safety reminders:"; then
  ok "check-migration emits warnings for a risky migration"
else
  bad "check-migration produced no warning (got: ${out:-<empty>})"
fi

# --- check-tdd.sh : expect the TDD nudge (app/ edited, no spec touched) ---
out="$(payload "$sandbox/app/models/post.rb" | bash "$HOOKS_DIR/check-tdd.sh" 2>&1)"
if echo "$out" | grep -q "TDD reminder:"; then
  ok "check-tdd emits the reminder for unspecced app/ code"
else
  bad "check-tdd produced no reminder (got: ${out:-<empty>})"
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

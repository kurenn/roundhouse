#!/usr/bin/env bash
# Migration safety check.
# Fires after every Edit/Write. Filters to db/migrate/*.rb internally.
# Surfaces common production-risky migration patterns. Stateless, zero token cost.

set -u

file="${CLAUDE_FILE:-}"
[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# Only fire for migration files.
case "$file" in
  */db/migrate/*.rb) ;;
  *) exit 0 ;;
esac

warnings=()

if grep -q "remove_column" "$file"; then
  warnings+=("removes a column — must be split across two deploys (deploy code that ignores the column first, then this migration)")
fi

if grep -q "add_index" "$file" && ! grep -q "algorithm: :concurrently" "$file"; then
  warnings+=("add_index without algorithm: :concurrently locks the table on Postgres in production; combine with disable_ddl_transaction!")
fi

if grep -q "change_column " "$file"; then
  warnings+=("change_column may rewrite the table; confirm the table size is small or use a multi-step approach")
fi

if grep -qE "add_reference|add_belongs_to" "$file" && ! grep -q "index:" "$file"; then
  warnings+=("add_reference / add_belongs_to without index: true — every belongs_to needs an index")
fi

if grep -qE "null:\s*false" "$file" && ! grep -qE "default:" "$file" && grep -q "add_column" "$file"; then
  warnings+=("add_column with null: false but no default — this fails on existing rows; add a default or backfill first")
fi

if [ ${#warnings[@]} -gt 0 ]; then
  printf "Migration safety reminders:\n"
  printf "  - %s\n" "${warnings[@]}"
fi

exit 0

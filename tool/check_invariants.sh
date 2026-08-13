#!/usr/bin/env bash
#
# The parts of CLAUDE.md that a machine can check.
#
# Rule 1 -- "every APK must upgrade the one before it" -- is the one mistake in
# this repository that destroys a student's data rather than wasting time, and
# until now it was enforced entirely by a human remembering to read a document.
# It had already failed twice: two profile APKs went out debug-signed, and a
# build escaped carrying versionCode 2001, which is higher than the real line
# will reach for years and which nothing can now upgrade.
#
# Prose does not run. This does.
#
# Usage:  tool/check_invariants.sh [base-ref]
#         base-ref defaults to origin/main and is only used for the
#         versionCode comparison, which needs something to compare against.

set -uo pipefail

BASE="${1:-origin/main}"
failures=0

fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf '  \033[32mok\033[0m    %s\n' "$1"; }
note() { printf '        %s\n' "$1"; }

echo
echo "Ather release invariants"
echo

# --- 1. applicationId ---------------------------------------------------------
# Changing it ships a second app beside the first with none of its data.
if grep -q 'applicationId = "com.ather.app"' android/app/build.gradle.kts; then
  pass "applicationId is com.ather.app"
else
  fail "applicationId is not com.ather.app"
  note "A different id installs as a separate app carrying none of the student's data."
fi

# --- 2. the release build still refuses the debug key -------------------------
# The refusal is the whole reason a debug-signed release cannot happen silently.
if grep -q 'buildingRelease && !hasReleaseKeystore' android/app/build.gradle.kts \
  && grep -q 'throw GradleException' android/app/build.gradle.kts; then
  pass "a release without a keystore fails the build"
else
  fail "the release build no longer refuses to fall back to the debug key"
  note "A debug-signed release can never upgrade a real install, and Play will not take it."
fi

# --- 3. versionCode never goes backwards --------------------------------------
current_version="$(grep -m1 '^version:' pubspec.yaml | sed 's/version:[[:space:]]*//')"
current_code="${current_version##*+}"

if ! [[ "$current_code" =~ ^[0-9]+$ ]]; then
  fail "cannot read a build number from pubspec.yaml ('$current_version')"
else
  if git rev-parse --verify --quiet "$BASE" >/dev/null; then
    base_version="$(git show "$BASE:pubspec.yaml" 2>/dev/null | grep -m1 '^version:' | sed 's/version:[[:space:]]*//')"
    base_code="${base_version##*+}"
    if [[ "$base_code" =~ ^[0-9]+$ ]]; then
      if [ "$current_code" -lt "$base_code" ]; then
        fail "versionCode went backwards: $base_code ($BASE) -> $current_code"
        note "Android refuses to install an APK whose versionCode is not higher than the installed one."
        note "The student's only way forward is uninstalling, which deletes their database."
      elif [ "$current_code" -eq "$base_code" ]; then
        pass "versionCode unchanged at $current_code (bump it before any APK leaves the machine)"
      else
        pass "versionCode $base_code -> $current_code"
      fi
    else
      note "skipped versionCode comparison: no readable version on $BASE"
    fi
  else
    note "skipped versionCode comparison: $BASE not available"
  fi
fi

# --- 4. the schema and its migration move together ----------------------------
# Bumping one without the other opens the app against a database missing a table
# it is about to read.
if git rev-parse --verify --quiet "$BASE" >/dev/null; then
  db_file="lib/data/db/app_database.dart"
  old_schema="$(git show "$BASE:$db_file" 2>/dev/null | grep -m1 'schemaVersion =>' || true)"
  new_schema="$(grep -m1 'schemaVersion =>' "$db_file" || true)"
  if [ -n "$old_schema" ] && [ "$old_schema" != "$new_schema" ]; then
    if git diff --name-only "$BASE"...HEAD | grep -q 'task_migration_test\|migration'; then
      pass "schemaVersion changed and a migration test changed with it"
    else
      fail "schemaVersion changed with no migration test touched"
      note "Every student carries the previous schema. Write the migration and a test that opens"
      note "a database at the old version -- never 'fix' a mismatch by recreating the file."
    fi
  else
    pass "schemaVersion unchanged"
  fi
fi

# --- 5. nothing half-merged ---------------------------------------------------
# PROJECT.md sat in main with two unresolved conflicts committed into it,
# including one that swallowed an entire work-log entry.
markers="$(git grep -I -l -E '^(<<<<<<<|>>>>>>>)' -- . ':(exclude)tool/check_invariants.sh' || true)"
if [ -z "$markers" ]; then
  pass "no conflict markers committed"
else
  fail "conflict markers committed in:"
  while IFS= read -r f; do note "$f"; done <<< "$markers"
fi

echo
if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed."
  exit 1
fi
echo "All invariants hold."

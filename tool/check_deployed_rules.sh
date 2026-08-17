#!/usr/bin/env bash
#
# Asks the *live* Firestore project the questions firestore.rules claims to
# answer, using two throwaway accounts.
#
# RELEASING.md §4a already says the deployed rules and the committed file can
# differ and that nobody can tell which is which by reading this repository.
# On 2026-08-16 they *did* differ, and the difference was measured with this
# check: the file in git refused a student deleting their own backup, the
# deployed rules allowed it. Since `deleteCloudData()` is the third step of
# in-app account deletion, that gap is the difference between erasure working
# and erasure failing after the device has already been wiped.
#
# So this is the other half of `firebase deploy --only firestore:rules`. Deploy,
# then run this. A deploy nobody verified is a rule change nobody has read.
#
# Usage:
#   tool/check_deployed_rules.sh <emailA> <passwordA> <emailB> <passwordB>
#
# The two accounts must be **throwaway test accounts on this project**. The
# check writes to and deletes account A's own backup document, which is exactly
# the data a real student cannot afford to lose. Nothing is passed on a command
# line that is not already a test credential; nothing is written to the repo.
#
# Requires: curl. The API key is read from google-services.json, where it
# already sits in the clear -- it is public client configuration, not a secret.

set -uo pipefail

if [ "$#" -ne 4 ]; then
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

EMAIL_A="$1"; PASS_A="$2"; EMAIL_B="$3"; PASS_B="$4"

failures=0
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; failures=$((failures + 1)); }
pass() { printf '  \033[32mok\033[0m    %s\n' "$1"; }
note() { printf '        %s\n' "$1"; }

GS="android/app/google-services.json"
[ -f "$GS" ] || { echo "cannot find $GS -- run from the repository root"; exit 2; }

KEY="$(tr -d ' \n' < "$GS" | grep -o '"current_key":"[^"]*"' | head -1 | cut -d'"' -f4)"
PROJECT="$(tr -d ' \n' < "$GS" | grep -o '"project_id":"[^"]*"' | head -1 | cut -d'"' -f4)"
[ -n "$KEY" ] && [ -n "$PROJECT" ] || { echo "could not read the API key or project id"; exit 2; }

BASE="https://firestore.googleapis.com/v1/projects/$PROJECT/databases/(default)/documents"

# --- sign both accounts in ----------------------------------------------------
signin() {
  curl -sS -X POST \
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$KEY" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"$2\",\"returnSecureToken\":true}"
}
# The whitespace is squeezed out first: Identity Toolkit pretty-prints its
# response, so `"idToken": "..."` carries a space the pattern would otherwise
# miss -- and a missed token reads exactly like a wrong password.
field() { tr -d ' \n' | grep -o "\"$1\":\"[^\"]*\"" | head -1 | cut -d'"' -f4; }

A_JSON="$(signin "$EMAIL_A" "$PASS_A")"
B_JSON="$(signin "$EMAIL_B" "$PASS_B")"
TOKEN_A="$(printf '%s' "$A_JSON" | field idToken)"
UID_A="$(printf '%s' "$A_JSON" | field localId)"
TOKEN_B="$(printf '%s' "$B_JSON" | field idToken)"

if [ -z "$TOKEN_A" ] || [ -z "$TOKEN_B" ]; then
  echo "could not sign in the two test accounts -- check the credentials"
  exit 2
fi

DOC="$BASE/users/$UID_A/backup/snapshot"

echo
echo "Ather deployed Firestore rules -- project $PROJECT"
echo

# `check <name> <expect allowed|denied> <curl args...>` -- 2xx counts as allowed.
check() {
  local name="$1" expect="$2"; shift 2
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' "$@")"
  local got="denied"
  [ "$code" -lt 400 ] && got="allowed"
  if [ "$got" = "$expect" ]; then
    pass "$name -> $got"
  else
    fail "$name -> $got (expected $expect, HTTP $code)"
  fi
}

BODY='{"fields":{"payload":{"bytesValue":""},"formatVersion":{"integerValue":"1"},"chapterCount":{"integerValue":"1"},"examCount":{"integerValue":"1"}}}'

# The whole confidentiality guarantee, in three lines.
check "student B cannot read student A's backup" denied \
  -H "Authorization: Bearer $TOKEN_B" "$DOC"
check "student B cannot overwrite it" denied \
  -X PATCH -H "Authorization: Bearer $TOKEN_B" -H "Content-Type: application/json" -d "$BODY" "$DOC"
check "an unauthenticated caller cannot read it" denied "$DOC"

# Anything outside users/{uid}/backup is meant to be unreachable from a client.
check "no writing outside the backup subcollection" denied \
  -X PATCH -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" \
  -d '{"fields":{"x":{"stringValue":"y"}}}' "$BASE/users/$UID_A/notes/probe"

# The owner's own path has to keep working, or backup is broken for everyone.
check "student A can write their own backup" allowed \
  -X PATCH -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -d "$BODY" "$DOC"
check "student A can read their own backup" allowed \
  -H "Authorization: Bearer $TOKEN_A" "$DOC"

# And the one that is easy to lose to a rule that only *looks* right: on a
# delete there is no request.resource, so any condition touching it denies.
check "student A can DELETE their own backup" allowed \
  -X DELETE -H "Authorization: Bearer $TOKEN_A" "$DOC"

echo
if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed against the deployed rules."
  note "If the delete check failed, in-app account deletion is broken: it wipes"
  note "the device first and then cannot remove the cloud copy or the account."
  exit 1
fi
echo "The deployed rules match what firestore.rules promises."

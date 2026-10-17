#!/usr/bin/env bash
# Runs the instrumented admin flows (integration_test/admin_test.dart) on an
# Android emulator against the LOCAL Firebase emulators: Auth and Firestore
# with the real firebase/firestore.rules, never the real project.
#
#   tool/admin_e2e.sh [device]      # device: emulator-5554 by default
#
# Needs: the Android emulator running (see CLAUDE.md), and the Firebase CLI
# installed in firebase/ (`cd firebase && npm ci`), with Java for the
# emulators. `emulators:exec` starts the emulators, runs the test, then
# stops them, whatever its result; nothing is kept between runs.
#
# The project id (demo-…) only names the emulators' default project: the
# app talks to them under its own project id, which they accept because
# firebase/firebase.json sets `singleProjectMode: false`.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
device="${1:-emulator-5554}"
firebase="$root/firebase/node_modules/.bin/firebase"

if [[ ! -x "$firebase" ]]; then
  echo "Firebase CLI missing: run (cd firebase && npm ci) first." >&2
  exit 1
fi

# firebase.json (rules, emulator ports) is read from firebase/.
cd "$root/firebase"
"$firebase" emulators:exec --only auth,firestore \
  --project demo-tournee-calendriers \
  "cd '$root' && flutter test integration_test/admin_test.dart -d '$device'"

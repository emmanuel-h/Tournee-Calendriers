#!/usr/bin/env bash
# Writes the Firebase settings that `flutterfire configure` makes and the
# public repository must not hold (PLAN §10.3), from two environment
# variables holding each file in base64:
#
#   FIREBASE_OPTIONS_DART  -> lib/bootstrap/firebase_options.dart
#   GOOGLE_SERVICES_JSON   -> android/app/google-services.json
#
# Usage, from the project root (CI sets the variables from secrets):
#   tool/write_firebase_config.sh
#
# Exit codes: 0 both written, 1 a variable is missing or not base64.

set -euo pipefail

write() {
  local name="$1" path="$2"
  local value="${!name:-}"
  if [[ -z "$value" ]]; then
    echo "$name is not set: add it as a secret (base64 of $path)." >&2
    exit 1
  fi
  if ! base64 --decode <<<"$value" >"$path" 2>/dev/null; then
    rm -f "$path"
    echo "$name is not valid base64 (expected: base64 -w0 $path)." >&2
    exit 1
  fi
}

write FIREBASE_OPTIONS_DART lib/bootstrap/firebase_options.dart
write GOOGLE_SERVICES_JSON android/app/google-services.json
echo "Firebase settings written."

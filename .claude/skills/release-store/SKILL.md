---
name: release-store
description: Automate the full Tournée Calendriers release workflow — ask for the version and the Play track, build the signed App Bundle, check its certificate, tag a GitHub release, and publish the bundle, its R8 mapping and French release notes (and, only if asked, the listing text and images) to Google Play. Use when the user wants to publish a new version to the Play Store or a testing track, including when they ask for a release bundle.
argument-hint: "[major|minor|hotfix]  (default: minor)"
allowed-tools: Bash Read Edit Glob Grep Write AskUserQuestion
---

Automate the Tournée Calendriers release, from version bump to Google Play.
Adapted from DiceRoller's `release-store` skill. **Never pick the version yourself**:
Step 5 always asks.

## Input

`$ARGUMENTS` contains the release type: `major`, `minor`, or `hotfix`.
Default to `minor` if absent or unrecognised. It only sets the recommended option in
Step 5; the user decides.

## What lives where

| Thing | Where |
|---|---|
| Version | `pubspec.yaml`, `version: <name>+<code>` (Flutter passes both to Gradle) |
| Upload key | `~/.config/tournee-calendriers/upload-keystore.jks`; its four settings `TOURNEE_RELEASE_KEYSTORE_FILE`, `…_KEYSTORE_PASSWORD`, `…_KEY_ALIAS`, `…_KEY_PASSWORD` in `~/.gradle/gradle.properties` (or the environment). Read by `android/app/build.gradle.kts`. Play App Signing holds the app key. |
| Upload key SHA-256 | `DE:CA:6C:1E:3C:46:8F:48:73:61:51:2B:17:2D:E2:21:D3:68:65:E2:2E:94:59:9B:03:47:44:84:75:7D:4A:6C` |
| Play service account | `~/.config/todolist/play-service-account.json` (or `$PLAY_SERVICE_ACCOUNT`), the developer account's one key, shared with Todolist and DiceRoller. It needs this app added under *Users and permissions*. |
| Publisher | `tool/publish_play.py` (one edit, committed once; a failure deletes it). `--dry-run` prints the calls, `--validate-only` has Play check the edit and discard it. |
| Listing material | `store/listing/` and `store/screenshots/fr-FR/` (T5.2 #36; may not exist yet) |

**What the API cannot do**, and the user does in the Console: create the app, fill in
*App content* (privacy policy, ads, data safety, content rating, target audience), set a
track's countries and testers (e-mail lists), and roll out the very first release.

The app is French only: listing and release notes are `fr-FR` only.

**Location privacy** (CLAUDE.md): release notes, the GitHub release and anything sent to
Play never name the private reference area.

---

## Step 1 — Parse the release type

```bash
RELEASE_TYPE="${ARGUMENTS:-minor}"
[[ "$RELEASE_TYPE" =~ ^(major|minor|hotfix)$ ]] || RELEASE_TYPE="minor"
```

## Step 2 — Read the current version

```bash
VERSION=$(grep -oP '^version:\s*\K\S+' pubspec.yaml)
CURRENT_NAME="${VERSION%+*}"; CURRENT_CODE="${VERSION#*+}"
echo "Current: $CURRENT_NAME (code $CURRENT_CODE)"
```

## Step 3 — Candidate versions

```bash
IFS='.' read -r MA MI PA <<< "$CURRENT_NAME"
NEW_CODE=$((CURRENT_CODE + 1))
MAJOR_NAME="$((MA + 1)).0.0"; MINOR_NAME="$MA.$((MI + 1)).0"; HOTFIX_NAME="$MA.$MI.$((PA + 1))"
```

**First release only:** if no `v*` tag exists (`git tag -l 'v*'` is empty) and Play has
never received a bundle, offer `$CURRENT_NAME` with code `$CURRENT_CODE` unchanged
(Recommended) instead of a bump.

## Step 4 — Preflight

Stop before changing anything if any check fails; never print key contents or passwords,
and never look for the keys anywhere else.

```bash
git status --porcelain            # must be empty
git rev-parse --abbrev-ref HEAD   # must be main, up to date with origin/main
PLAY_KEY="${PLAY_SERVICE_ACCOUNT:-$HOME/.config/todolist/play-service-account.json}"
test -f "$PLAY_KEY" && echo "Play key ok" || echo "MISSING Play key"
grep -c '^TOURNEE_RELEASE' ~/.gradle/gradle.properties   # expect 4 (names only)
test -f ~/.config/tournee-calendriers/upload-keystore.jks && echo "keystore ok"
test -f lib/bootstrap/firebase_options.dart && test -f android/app/google-services.json && echo "firebase config ok"
python3 -c 'import jwt, requests'
```

Then the fast gates: `flutter analyze` and `flutter test`. The instrumented suite already
ran before main was pushed (CLAUDE.md, Task workflow); do not re-run it here.

## Step 5 — Ask the user

One `AskUserQuestion` call; every option carries a `preview` showing what it produces
(the user's global instructions require it on every option).

1. **Version** — "Release $CURRENT_NAME (code $CURRENT_CODE) as …?" Options: the
   `$RELEASE_TYPE` bump (Recommended), the two others with their numbers, and "Don't
   release". Preview: the `pubspec.yaml` diff and the tag.
2. **Track** — "Which Play track?" Options: `internal` (Recommended until the closed test
   exists: the team's testers, no review, minutes), `alpha` (closed test), `production`
   (after Google's review). Preview: who receives the build.
3. Only if `store/listing/` exists — **Listing text**: "No — keep the Console's text"
   (Recommended) / "Yes — upload `store/listing/`" (preview: the title and short
   description that would replace the Console's).
4. Only if `store/listing/` or `store/screenshots/` exists — **Images**: "None"
   (Recommended) / "Screenshots" / "Icon and feature graphic" / "Both" (preview: the
   files and the Play slots they replace).

On "Don't release", stop. Keep `NEW_NAME`, `NEW_CODE`, `TRACK`, `LISTING`, `SCREENSHOTS`,
`GRAPHICS`. **Upload nothing the user did not choose here.**

## Step 6 — Patch `pubspec.yaml`

```bash
sed -i "s/^version:.*/version: ${NEW_NAME}+${NEW_CODE}/" pubspec.yaml
grep '^version' pubspec.yaml
```

Then the in-app « Nouveautés » (PLAN §5.9), which ships inside the app: add the version at
the top of `shippedReleases` in `lib/ui/screens/settings/changelog.dart`, with today's
date, and its lines to `lib/ui/l10n/app_fr.arb` as `release<digits>…` keys (e.g.
`release020Map`), the same French lines as the Play notes of Step 10 (write those first).
Run `flutter gen-l10n`, fix the tests that name the version
(`test/ui/screens/settings_screen_test.dart`), then `flutter analyze`, `flutter test`
and the coverage gate.

## Step 7 — Build and check the bundle

```bash
flutter build appbundle --release
AAB=build/app/outputs/bundle/release/app-release.aab
MAPPING=build/app/outputs/mapping/release/mapping.txt
keytool -printcert -jarfile "$AAB" | grep SHA256
```

The SHA-256 **must** be the upload key's (table above). Any other value means the build
fell back to the debug key (the four settings were not found): stop, Play would refuse it.
`$MAPPING` exists because R8 runs in release builds; it goes up with the bundle so Play's
crash reports are readable.

## Step 8 — Commit, tag and push

```bash
git add pubspec.yaml
git commit -m "Release ${NEW_NAME} (code ${NEW_CODE})"
git push
```

No AI attribution in the commit message.

## Step 9 — GitHub release

```bash
TAG="v${NEW_NAME}"
gh release create "$TAG" --title "$TAG" --generate-notes
```

**Do not attach the `.aab`**: the repository is public and the bundle carries the Firebase
settings kept out of it (PLAN §10.3). Play and the local `build/` hold the bundle.

## Step 10 — Release notes (French)

```bash
PREV_TAG=$(git tag -l 'v*' --sort=-v:refname | sed -n 2p)
git log "${PREV_TAG}..HEAD" --no-merges --format='%h %s'
```

Commits here are plain sentences, not conventional commits: keep the ones a user would
notice, merge those describing the same change, drop the invisible ones (tests, CI, docs,
refactors). Rewrite them as short French lines, in the app's vocabulary (tournée, rue,
maison, équipe), with no issue numbers, hashes or class names. With no previous tag:
`- Première version de test.` With nothing visible:
`- Améliorations internes et corrections mineures.`

**Play rejects notes over 500 characters**; aim for ≤ 460.

```bash
NOTES="<scratchpad>/notes"; mkdir -p "$NOTES"
cat > "$NOTES/fr-FR.txt" <<'EOF'
- …
EOF
wc -m "$NOTES/fr-FR.txt"
```

## Step 11 — Publish to Google Play

```bash
FLAGS="--bundle $AAB --mapping $MAPPING --track $TRACK --release-name $NEW_NAME --notes-dir $NOTES \
  $([ "$LISTING" = yes ] && echo --listing) \
  $([ "$SCREENSHOTS" = yes ] && echo --screenshots) \
  $([ "$GRAPHICS" = yes ] && echo --graphics)"
python3 tool/publish_play.py $FLAGS --validate-only
python3 tool/publish_play.py $FLAGS
```

On failure the script deletes the edit, so nothing half-done reaches Play:
- **"Only releases with status draft may be created on draft app"** (the app was never
  published): re-run with `--status draft`, and tell the user to start the rollout in the
  Console (*Testing → Internal testing*).
- **"Changes cannot be sent for review automatically"**: re-run with
  `--changes-not-sent-for-review`; the user presses *Send for review* in the Console.
- **"version code … already been used"**: do not bump again on your own; report it.
- **401 / 403, or "Package not found"**: the app does not exist in the Console yet, or the
  service account lacks it under *Users and permissions*.

Any other failure: show the error and stop. The tag and the pushed version already exist,
so only this step needs re-running once the cause is fixed.

## Step 12 — App Check after the first upload

Once Play holds a bundle, Play App Signing has made the app key. Remind the user, if not
done yet (#68): copy its SHA-256 from *Test and release → App integrity → App signing* into
Firebase (*Project settings → Android app → SHA certificate fingerprints*, with the upload
key's), and link the Cloud project for Play Integrity there. Without it, builds installed
from Play are refused once App Check is enforced.

## Summary output

```
✓ Version   : $CURRENT_NAME (code $CURRENT_CODE) → $NEW_NAME (code $NEW_CODE)
✓ AAB       : build/app/outputs/bundle/release/app-release.aab (upload key ✓, mapping ✓)
✓ GitHub    : https://github.com/emmanuel-h/Tournee-Calendriers/releases/tag/$TAG
✓ Play      : $NEW_NAME on $TRACK (completed | draft: roll out in the Console)
✓ Listing   : text updated | unchanged; images: … | unchanged
✓ Notes     : fr-FR <n> characters
```

Then show the release notes.

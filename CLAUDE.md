# CLAUDE.md

Guidance for Claude Code in this repository.

## Project

**Tournée Calendriers** (`fr.mandarine.tourneecalendriers`): an app firefighters use to mark the
houses visited during the yearly calendar round, shared live across a team. **Flutter + Riverpod**,
strict DDD (hexagonal), Firebase (Firestore + anonymous auth + App Check), MapLibre map, BAN
address APIs. Android first; iOS later from the same code (cloud build, no Mac).

- **The UI is entirely in French**; code identifiers and docs stay in English.
- Once a tournée is downloaded the app must work **fully offline** (map included) and sync later.

**`docs/PLAN.md` is the authoritative product and architecture definition**: screens (with
ASCII sketches), domain model, decisions, testing strategy. Read it before any feature work. Do
not implement anything that contradicts it; flag conflicts to the user first.
**`docs/mockups/`** holds the approved visual mockups (one `.dc.html` per screen) and the design
tokens in its README.

**Tasks are GitHub issues** (milestones M0–M7, label `task`); `docs/TASKS.md` is only a map of
them. Read a task with `gh issue view <N>`. Commits reference their task with `Refs #<N>` —
**never `Closes`/`Fixes`**: an issue is closed only when the user says so.

The user is still learning Dart and Flutter: explain non-obvious concepts briefly when you
introduce them.

## Status

Scaffolded with design system (T0.1–T0.2): Flutter 3.47.6 / Dart 3.13.5, layers, theme, French l10n, go_router shell, components. CI on every push and pull request (T0.3).
M1 done, milestone closed (2026-10-17) (#5–#14, #46, #15): street domain, BAN import, phone storage,
start screen, street screen, house sheet, buildings, edit mode; field-tested by the user.
M2 done, milestone closed (2026-10-17): onboarding (#21), Firebase (Spark) wired in `bootstrap/`, App Check,
anonymous sign-in (#17, #67); Tournée aggregate (#18); Firestore adapters (#19); security rules in
`firebase/` (#20); Équipe and Corbeille (#22); Mes tournées and Paramètres (#23); streets of the
open tournée on Firestore, phone storage when none is open (#24); pending-sync line (#25). Validated
by the user (2026-10-16); App Check enforced on Firestore and Auth (#68). Admins (#75): global `admins/{uid}` added by hand in the console, « Tous les secteurs », admin visit; validated by the user and closed (2026-10-17), rules deployed. Revoked admins and the emulator-based admin flow (#87) closed (2026-10-17).
Code audit clean-up (#88) and « Modifié par Léa » on the house and door sheets (#89) closed
(2026-10-17). #90 open: go_router 18.1 and Firebase (firebase_core 5.1, cloud_firestore 7.1, firebase_auth 7.0,
firebase_app_check 0.5.1, fake_cloud_firestore 4.5) done; the fake still cannot read a one-segment
`FieldPath`, so `FirestoreStreetRepository.save` keeps writing top-level fields by name. #69: rules tooling in `firebase/` upgraded to firebase-tools
15.34, rules-unit-testing 5, firebase 12 (Node ≥ 20; 22 locally and in CI); the Firestore
emulator's stale reads are gone (`tool/admin_e2e.sh` 6/6 in a row, 2026-11-02).
M3 done, milestone closed (2026-11-01): geometry and map layers (#26), geopf adapters (#27), street-picking use cases with shapes and assignees (#28), MapLibre map widget in `ui/map/` (#29), a tournée's communes and « Ajouter des rues » Carte | Liste (#78), Accueil (#30), the street card, search and manual street (#31), tries with nobody home (#80), the sheet on a tap to ↻ with a day + hour (#81). Follow-ups from the phone test: street shapes from the OpenFreeMap vector tiles instead of Overpass, filled once for streets without one (#92); take a street from « Autres rues » (#93). A street held only by ex-members of the team is « libre » (#91, display only, no rules change). Rules (with the #92 shape fill) deployed 2026-10-18 and identical to `firestore.rules` (checked 2026-11-01).
M4 done, milestone closed (2026-11-02): the open tournée
downloads itself for offline use, unseen (#32: streets into the cache + MapLibre region, silent
re-download for OpenFreeMap's weekly tiles); one line in Paramètres and tournées greyed
« Disponible avec réseau » offline (#33); airplane-mode day (#34).
M5 done, milestone closed (2026-11-02): launcher icon, themed icon and launch
screen (#101); rules tooling on firebase-tools 15 (#69); each house of a bulk street write checked
in the rules, 2 per write, sent in order (#70, `OrderedWrites`; those rules deployed 2026-11-02); Firebase 7 (#90); dark
palette reviewed and 200 % text checked (#35); the user's Confidentialité text (#79) and the
policy in `PRIVACY.md` linked from it; MIT `LICENSE`; Play listing texts, icon, feature graphic
and screenshots in `store/` (#36). Follow-ups: #102–#105.
Release signing and Play publishing (#37): publish with the `release-store` skill; versions are GitHub releases. `lib/bootstrap/firebase_options.dart` and `android/app/google-services.json`
are gitignored: run `flutterfire configure --out=lib/bootstrap/firebase_options.dart` locally;
CI writes them from secrets.
M5 follow-ups (2026-11-02); M5 closed by the user (2026-11-02): built-in Kotlin (#103; Flutter still
warns about firebase_core/auth/app_check, a false positive of its text check, flutter/flutter#189770);
a new street cut off mid-write is caught up at the next start (#104, `UnfinishedStreets`; debug log
« Street … written » to time a 300-number street); streets per member in Équipe, bottom buttons
pinned (#105). #102 waits for a firebase-tools release past 15.34.2.
M8 done (2026-11-03), validated by the user, milestone closed (2026-11-10): code and Firestore renamed `Tournee` → `Sector` (`sectors/`, `sectorKeys/`; phone files keep
their old names) and the outing is `Round` (#116, #115); status picker instead of the tap cycle (#107); « Refusé »
⊘ (#113); tournées with their dons, kept in `open_round.json` until validated, then a create-only summary under
`campaigns/{year}/rounds/` without its member (#108–#110); calendars per ✓ house (#114); « Collecte 2026 » in
Équipe (#111); privacy text drafted by Claude for the user's review (#112). No data migration: the old
`tournees`, `tourneeKeys`, `joinCodes` were deleted (single user) and the test secteurs are created again. Rules deployed 2026-11-03 (the user).
M9 planned (2026-11-03, #120–#125, PLAN §5.14): preparing the secteur and being on a tournée on separate
screens; no attribution (the secteur covers all its streets); « Ajouter des rues » in Secteur (🗺) with several
roads and a zone; houses marked only during a tournée; « En tournée » band on top (white, red edge).
M9 done, validated by the user, milestone closed (2026-11-11, #120–#125, #132, #134–#137): no attribution (#120); the Secteur button
(🗺, `Icons.map_outlined`) and « RUES (n) » with « + Ajouter des rues » and the Corbeille in Secteur,
no « Ajouter des rues » on Accueil (#121); houses marked only during a tournée (#122: with none on, a tap
on a house, a door or a building's « Repasser » says « Commencez une tournée… » with « Commencer », or
« Seuls les membres en tournée… » to a visiting admin; `MarkingAccess`); the « En tournée » band on top
(#123: in place of Accueil's top bar, so no secteur switch, Secteur or ⚙ during a tournée; above the
street's top bar and the building grid's header; the tournée card and the street's line are gone);
« Ajouter des rues » ticks several roads on « Carte » and adds them at once from a selection sheet
(#124: `PickedRoad` on the map, no street card on that screen); « Zone » draws a rectangle and lists its
streets (#125: `StreetShapes.roadsIn`, `FindZoneStreets` matching the tiles' road names to the BAN's in the
3 nearest communes, numbers read when added, `ZoneDrawing` over the map, zoom ≥ 15, 50 streets).
Rules without `assignees` deployed 2026-11-10 (identical to `firestore.rules`).
From the 0.11.0 phone test: « Ajouter des rues » stays open after adding, zone at any zoom, two fingers pan in
« Zone », a tap names the road under the finger from the tiles and the BAN street of that name, tolerating a map
typo (`StreetName.typosFrom`, also in « Zone ») (#134); the title opens Secteur, « Changer de secteur » in it
(#135); « Abandonner la tournée » in the Bilan (#136). The commune search falls back to the Géoplateforme when
geo.api.gouv.fr fails; « Pas de réseau » only for a real lack of network (`meansNoNetwork`), otherwise « Impossible
de … pour l'instant. Réessayez plus tard. » (#137). The map keeps the drawn zone, or the latest ✓, clear of the sheet
(`keepInView`, `cameraReveal`, moving as little as possible); the ✓ sits on the road under the finger (#132).
M10 done, validated by the user, milestone closed (2026-11-11, #138–#142, PLAN §5.15, from #133): a street split between secteurs. A part per side
(all / none / a range) stored on the street, numbers outside never stored; « Partie de la rue » with two marks on
the map snapping between house dots, opened when adding and from edit mode; a shared `streetParts/{banId}` index
(get only) shows other secteurs' stretches, warning on overlap, never blocking; the map draws only the held stretch.
Rules with `part` and `streetParts/{banId}` deployed 2026-11-11 (identical to `firestore.rules`).
M11 planned (2026-11-11, #143–#159): follow-ups of the security, reliability and DDD audit of that day, each with a
`severity: medium | low | info` label. Medium: a validated tournée kept on the phone until the server has it (#143);
the privacy text against what the app does (campaign erasure, Android backup, #144); unattributed tournée summaries
(#145). #143 needs a screen decision and #145 a risk decision before any code.
M11 done, validated by the user, milestone closed (2026-11-12, PLAN §5.16): #143–#159; #146 (App Check
and quota) checked by the user in the console. Rules changed (#145, #147 `openSectors/{uid}`, #148 `names/{key}`), deployed 2026-11-12
(identical to `firestore.rules`). Live secteurs and streets deleted 2026-11-12; the user started again from the phone.
#160: the user reviews every string in `lib/ui/l10n/app_fr.arb`.

## Commands

```bash
flutter test test/domain/street/house_number_test.dart   # inner TDD loop: one file
flutter test                                             # all tests, < 1 min
flutter test --coverage && tool/check_coverage.sh        # 100 % line coverage gate
flutter analyze                                          # zero warnings
dart format --set-exit-if-changed lib test
(cd firebase && npm test)                                # security rules in the emulator
flutter build appbundle --release                        # release-only breakage
python3 tool/publish_play.py --help                      # Play publishing (driven by /release-store)
tool/render_play_icon.py                                 # 512 px Play icon from the launcher drawables
flutter test integration_test/app_test.dart -d emulator-5554 --dart-define-from-file=$HOME/.config/tournee-calendriers/app_check_debug.json
tool/admin_e2e.sh                                        # admin flows, local Auth + Firestore emulators
tool/store_screenshots.sh                                # Play screenshots → store/screenshots/fr-FR/ (not a suite)
flutter run --dart-define-from-file=$HOME/.config/tournee-calendriers/app_check_debug.json
```

The `--dart-define-from-file` gives debug builds the App Check debug token registered in the
Firebase console (`lib/bootstrap/firebase.dart`); without it they are refused once App Check
is enforced. The file is local only (the token is a secret).

Emulator: `~/Android/Sdk/emulator/emulator -avd Medium_Phone_API_36.1 -no-window -no-audio`
(headless); screenshots with `adb exec-out screencap -p > shot.png`.

## Architecture (strict DDD, hexagonal)

```
lib/
├── domain/          aggregates, entities, value objects, domain services, repository ports
├── application/     use cases (one class, one `call`) + outbound ports
├── infrastructure/  adapters: Firestore, geopf/BAN/OpenFreeMap tiles (http), MapLibre offline, auth, prefs
├── presentation/    Riverpod Notifiers + immutable view states (use cases only)
├── ui/              Flutter widgets: screens, theme/, components/, map/
└── bootstrap/       composition root: Firebase init, providers binding ports → adapters
```

- Dependencies point inward only: `ui → presentation → application → domain`;
  `infrastructure → application/domain`; only `bootstrap` sees everything. `ui` may name domain
  value types; `presentation` uses Riverpod but not Flutter.
  `test/architecture_test.dart` enforces it.
- `domain/` is pure Dart: no Flutter, Firebase, http, MapLibre.
- Behaviour enters only through use cases; aggregates change only through their root.

## Conventions

- Comments explain *why* and non-obvious Dart/Flutter concepts; never restate the code.
- Every user-visible string is French, in `lib/ui/l10n/app_fr.arb` (no other locale).
- Status is never conveyed by colour alone (glyph + text / semantics label).
- Nothing on the marking path may need the network: it must work after an offline cold start.
- Screens are agreed in two steps: ASCII variants in the terminal first (before/after when
  changing) so the user can choose, then a visual mockup to confirm. Only then implement.
  Keep `PLAN.md` §5 and `docs/mockups/` in sync.
- No code generation (no freezed, no riverpod_generator, no build_runner).
- **Location privacy:** the real reference area used for field tests is private. Never write it
  (name, postcode, street names, coordinates) into the repo, commits, issues, test fixtures,
  screenshots or store assets. Everything public that needs a place uses
  **Villefranche-sur-Saône** (69400, INSEE 69264). The real area is only entered on the phone.
- Tests: `test` / `flutter_test`, hand-written fakes for ports, `mocktail` only for verified
  collaborators; names `'should <behaviour> when <condition>'`; the inner loop runs one file.
  Slow suites (rules emulator, release build) run once per task and in CI.

## Task workflow

1. The `developer` agent delivers one issue on a branch; it never commits.
2. The main session reviews the diff, re-runs the gates, runs the **instrumented suite on the
   emulator** and looks at the changed screens on the emulator (screenshots).
3. Commit with `Refs #<N>`, merge into `main` and **push** (standing approval).
4. Ask the user to test on their phone; fix what they report (same loop).
5. The user decides when the issue is closed; close it with `gh issue close` only when told.

**Instrumented suite** (`integration_test/`): small on purpose — a handful of end-to-end flows
on the real app (launch, mark a house, offline cold start…), ≤ 10 tests, < 3 min. Extend it when
a task adds a user-visible flow; keep it green before every push. Two files, run separately (each
is its own app process): `app_test.dart` on the real project, Firestore offline; `admin_test.dart`
(admin flows, #87) against the **local Firebase emulators** (Auth + Firestore with the real rules,
`tool/admin_e2e.sh` starts and stops them). `store_screenshots_test.dart` is not part of the suite: it only makes the Play Store
screenshots, through `tool/store_screenshots.sh`. Never `flutter test integration_test` on the whole
folder: `admin_test.dart` fails without the emulators. Debug builds may reach `10.0.2.2` over
plain HTTP for this (`android/app/src/debug/`); release builds may not.

## Infrastructure (decided at the M2 checkpoint)

Firebase **Spark** (free), Blaze-ready: no Cloud Functions; the join stays on the phone behind
the `SectorDirectory` port so a server-side join is only an adapter swap later (PLAN Q20).

## Agents

- **`developer`** (`.claude/agents/developer.md`) implements one task (a GitHub issue) end to end
  with TDD and the gates. It never commits; the main session reviews, commits with `Refs #<N>`,
  pushes, and opens a follow-up issue for anything deferred.

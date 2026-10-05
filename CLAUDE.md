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
M1 code delivered (#5–#14, #46, #15): street domain, BAN import, phone storage, start screen, street
screen, house sheet, buildings, edit mode; awaiting the user's field test (#15).

## Commands

```bash
flutter test test/domain/street/house_number_test.dart   # inner TDD loop: one file
flutter test                                             # all tests, < 1 min
flutter test --coverage && tool/check_coverage.sh        # 100 % line coverage gate
flutter analyze                                          # zero warnings
dart format --set-exit-if-changed lib test
(cd firebase && npm test)                                # security rules in the emulator
flutter build appbundle --release                        # release-only breakage
flutter test integration_test -d emulator-5554           # instrumented suite on the emulator
flutter run                                              # on a connected Android phone
```

Emulator: `~/Android/Sdk/emulator/emulator -avd Medium_Phone_API_36.1 -no-window -no-audio`
(headless); screenshots with `adb exec-out screencap -p > shot.png`.

## Architecture (strict DDD, hexagonal)

```
lib/
├── domain/          aggregates, entities, value objects, domain services, repository ports
├── application/     use cases (one class, one `call`) + outbound ports
├── infrastructure/  adapters: Firestore, geopf/BAN/Overpass (http), MapLibre offline, auth, prefs
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
a task adds a user-visible flow; keep it green before every push.

## Open checkpoint

At the start of M2 (database and server work), **stop and discuss the infrastructure with the
user** before writing data code: Firebase Spark vs Blaze, server-side join with rate limiting,
or another backend (PLAN §8.1, Q20).

## Agents

- **`developer`** (`.claude/agents/developer.md`) implements one task (a GitHub issue) end to end
  with TDD and the gates. It never commits; the main session reviews, commits with `Refs #<N>`,
  pushes, and opens a follow-up issue for anything deferred.

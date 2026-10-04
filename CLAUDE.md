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
them. Read a task with `gh issue view <N>`. Commits that finish a task say `Closes #<N>`.

The user is still learning Dart and Flutter: explain non-obvious concepts briefly when you
introduce them.

## Status

Planning done. The project is not scaffolded yet; the commands below become valid after M0.

## Commands

```bash
flutter test test/domain/street/house_number_test.dart   # inner TDD loop: one file
flutter test                                             # all tests, < 1 min
flutter test --coverage && tool/check_coverage.sh        # 100 % line coverage gate
flutter analyze                                          # zero warnings
dart format --set-exit-if-changed lib test
(cd firebase && npm test)                                # security rules in the emulator
flutter build appbundle --release                        # release-only breakage
flutter run                                              # on a connected Android phone
```

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
  `infrastructure → application/domain`; only `bootstrap` sees everything.
  `test/architecture_test.dart` enforces it.
- `domain/` is pure Dart: no Flutter, Firebase, http, MapLibre.
- Behaviour enters only through use cases; aggregates change only through their root.

## Conventions

- Comments explain *why* and non-obvious Dart/Flutter concepts; never restate the code.
- Every user-visible string is French, in `lib/l10n/app_fr.arb` (no other locale).
- Status is never conveyed by colour alone (glyph + text / semantics label).
- Nothing on the marking path may need the network: it must work after an offline cold start.
- Screens are agreed in two steps: ASCII variants in the terminal first (before/after when
  changing) so the user can choose, then a visual mockup to confirm. Only then implement.
  Keep `PLAN.md` §5 and `docs/mockups/` in sync.
- No code generation (no freezed, no riverpod_generator, no build_runner).
- Tests: `test` / `flutter_test`, hand-written fakes for ports, `mocktail` only for verified
  collaborators; names `'should <behaviour> when <condition>'`; the inner loop runs one file.
  Slow suites (rules emulator, release build) run once per task and in CI.

## Open checkpoint

At the start of M2 (database and server work), **stop and discuss the infrastructure with the
user** before writing data code: Firebase Spark vs Blaze, server-side join with rate limiting,
or another backend (PLAN §8.1, Q20).

## Agents

- **`developer`** (`.claude/agents/developer.md`) implements one task (a GitHub issue) end to end
  with TDD and the gates. It never commits; the main session reviews, commits with
  `Closes #<N>`, and opens a follow-up issue for anything deferred.

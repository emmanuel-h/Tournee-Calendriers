# Tasks

Status: **approved** · 2026-10-04. Source of truth for scope: `docs/PLAN.md`; screens:
`docs/mockups/`.

How to use this file:

- One task = one run of the `developer` agent = one reviewable commit. Tasks are ordered;
  a task only depends on tasks above it.
- **[you]** marks a step only you can do (accounts, a phone in your hand, a decision).
- Every agent task ends with the gates from `CLAUDE.md` (analyze, format, tests, 100 % coverage
  on gated paths). Acceptance criteria below are *in addition* to those.
- Tick `[x]` when merged. Note anything deferred under the task.

Milestone overview:

| # | Milestone | Tasks | You can try on a phone |
|---|---|---|---|
| M0 | Foundations | T0.1 – T0.4 | an empty themed app and a map that works offline |
| M1 | The street, on a real area | T1.1 – T1.11 | the whole marking experience on real streets, no backend yet |
| M2 | Team and sync | T2.0 – T2.9 | two phones see each other's marks |
| M3 | Map and streets | T3.1 – T3.6 | real streets picked on the map |
| M4 | Offline | T4.1 – T4.3 | a full day in airplane mode |
| M5 | Release (Android) | T5.1 – T5.3 | the app on the Play Store (internal testing) |
| M6 | Next year (v1.1) | T6.1 – T6.3 | tournée 49 starts 2027 from 2026 |
| M7 | iOS (when the Apple account exists) | T7.1 – T7.2 | the app on an iPhone via TestFlight |

---

## M0 — Foundations

### [ ] T0.1 Project skeleton and guard rails
- `flutter create` (Android + iOS folders), app id `fr.mandarine.tourneecalendriers`, minSdk 26.
- `lib/` layers from PLAN §10.1 with a placeholder file each; `bootstrap/` with `ProviderScope`.
- `analysis_options.yaml` strict; `test/architecture_test.dart` enforcing the dependency rule.
- `tool/check_coverage.sh`: fails under 100 % line coverage on `domain/`, `application/`,
  `presentation/` and `infrastructure/**/mappers` (excluded paths listed in the script).
- **Accept:** `flutter analyze` clean; architecture test fails when a domain file imports
  Flutter (proved by a test fixture, not by breaking real code); coverage script fails on an
  uncovered gated file and passes otherwise; `flutter run` shows a blank French-titled screen.

### [ ] T0.2 Design system and app shell
- Theme from `docs/mockups/README.md` tokens (light; dark tokens prepared, wired in T5.1).
- Fonts bundled (Atkinson Hyperlegible, Barlow Condensed, OFL notices).
- French localisation (`app_fr.arb`), `go_router` with empty routes for every screen of PLAN §5.
- Shared components: primary / secondary buttons, status tile (4 statuses + building), bottom
  sheet scaffold, section header, snackbar with action.
- **Accept:** widget tests for the status tile (glyph + semantics label per status, ≥ 56 dp);
  a `components` gallery route (debug builds only) renders every component.

### [ ] T0.3 Continuous integration
- `.github/workflows/checks.yml`: analyze + format, tests + coverage gate, `flutter build
  appbundle --release` (unsigned in CI). Rules job added in T2.4.
- **Accept:** workflow green on a PR; a deliberately failing test on a throwaway branch makes
  it red.

### [ ] T0.4 Spike: map and offline tiles  · *throwaway branch, report only*
- `maplibre_gl` + OpenFreeMap style on a test screen; draw a GeoJSON line and a dot; tap returns
  coordinates; download an offline region (the **reference area**, z12–17) and display it in
  airplane mode. Check OpenFreeMap's terms on offline/bulk download; IGN Plan as fallback.
- **Accept:** written report in `docs/spikes/map.md` (works / doesn't, region size, tile count,
  terms, gotchas); **[you]** confirm on your phone that the map shows in airplane mode.

---

## M1 — The street, on a real area

**No invented data.** M1 runs on a **reference area** you choose (a commune and a handful of
streets you can walk). Its streets and house numbers come from the BAN, as in production;
marks are stored on the phone until Firestore replaces that storage in M2 behind the same port.

Reference area: **[you] to choose** — commune: ______ · streets: ______


### [ ] T1.1 House numbers and statuses (domain)
- Value objects `HouseNumber` (parse `12`, `12bis`, `12 B`, `3A`; French ordering
  `3 < 3bis < 3ter < 3quater < 3A < 4`; odd/even), `VisitStatus` (+ tap cycle), `ComeBack`, `Note`
  (≤ 200 chars).
- **Accept:** parsing table tests incl. invalid inputs returning a failure; ordering tests;
  cycle `toDo → done → nobodyHome → toDo`.

### [ ] T1.2 Street aggregate
- `Street` root with houses, `markHouse`, `setComeBack`, `setNote`, `progress`, odd/even split,
  `StreetChange` sealed family, soft delete flag.
- **Accept:** invariants (unique numbers, sorted houses); each method returns the right change;
  progress counts (done / nobody / come back / to do / total) on mixed streets.

### [ ] T1.3 Buildings (domain)
- `Building` → `Staircase` → `Floor` → `Dwelling`; layout generation from (staircases, floors
  RdC…n, doors per floor, label style `51` / `5A` / free); per-floor adjust; derived building
  status; `markDwelling`; layout change keeps statuses of surviving labels.
- **Accept:** generation tables; derived status (all done / none / partial); relayout keeps
  statuses.

### [ ] T1.4 Editing numbers (domain)
- Range expression parser (`12bis, 21-25`, sides both/odd/even, extras); `addNumbers`,
  `removeNumber` (soft), `renameNumber`, `restoreNumber`; manual street factory.
- **Accept:** parser tables incl. errors; removing a number with a status is allowed but flagged
  so the UI can confirm; restore brings back status and note.

### [ ] T1.5 BAN adapter (real streets and numbers)
- `AddressDirectory` port (part used now: streets of a commune, numbers of a street with
  positions) + adapter on BAN `lookup` (http), with JSON fixtures captured from the reference
  area. (Reverse geocoding and search are added in T3.2.)
- **Accept:** parsing tests on the captured fixtures (suffixes, positions, empty street);
  network failure maps to a failure value.

### [ ] T1.6 Street use cases and on-phone storage
- Ports `StreetRepository`, `Clock`, `IdGenerator`; a local adapter persisting streets as JSON
  on the phone (`path_provider`), so marks survive a restart during the real walk. In-memory
  fake for tests. Use cases `ImportReferenceArea` (commune + chosen streets → BAN → repository),
  `ObserveStreet`, `MarkHouse`, `UndoLastChange`, `SetHouseDetails`, `EditStreetNumbers`,
  `DescribeBuilding`, `MarkDwelling`.
- **Accept:** each use case tested with fakes; undo restores the exact previous house; local
  adapter round-trips a street; marks persist across a simulated restart.

### [ ] T1.7 Street screen
- Mockup `Main`: two columns odd/even scrolling together, status tiles, header counts and
  progress bar, "Masquer faits", tap cycles with haptic tick, undo snackbar (4 s), building tile
  opens the grid, ✏ opens edit mode.
- **Accept:** widget tests: tap cycles and announces; undo restores; hide done; single column
  when one side is empty.

### [ ] T1.8 House sheet
- Mockup `House`: long-press opens it; status segmented control, Repasser + hint, note with the
  privacy hint, "Transformer en immeuble…", last change line.
- **Accept:** widget test long-press → sheet → set Repasser → tile shows ↻.

### [ ] T1.9 Building grid and "Décrire l'immeuble"
- Mockups `Building`, `BuildingSetup`: floors top to bottom, wrapping rows, staircase chips only
  when > 1, tap cycles a door, long-press door details; setup sheet with steppers and label style.
- **Accept:** widget tests: tap a door cycles and updates the header count; staircase switch.

### [ ] T1.10 Edit mode and "Ajouter des numéros"
- Mockups `Edit`, `Numbers`: rename street, ✕ remove with undo (confirm when a status exists),
  "+ numéros" sheet with live preview, tap a number → rename / make building, bottom actions.
- **Accept:** widget tests: remove + undo; add `21-25` lands on the right sides.

### [ ] T1.11 Field build on the reference area  · **[you]**
- Temporary start screen: import the reference area (once, needs network), list its streets →
  Street screen. Release a debug APK.
- **Accept:** **[you]** walk a real street with the demo and send feedback; feedback becomes
  tasks or plan changes before M2.

---

## M2 — Team and sync

### [ ] T2.0 Infrastructure checkpoint  · **[you] + main session**
- Decide: Firebase Spark vs Blaze (server-side join with rate limiting), or another backend.
  Record the decision in PLAN §8.1 / §13. **No data code before this.**

### [ ] T2.1 Firebase project and bootstrap  · **[you]** for the console part
- **[you]** create the project (europe-west, anonymous auth, App Check), run `flutterfire
  configure`. Agent: Firebase init in `bootstrap/`, App Check (debug provider in debug builds),
  `IdentityProvider` port + Firebase adapter, CI secrets for `firebase_options.dart` /
  `google-services.json`.
- **Accept:** app signs in anonymously on first launch and keeps the same uid across restarts.

### [ ] T2.2 Tournée aggregate (domain)
- `Tournee`, `Member` (pending / active), `JoinCode` (generation with injected random,
  normalisation), `RescueCentre` + key normalisation, `CampaignYear`; rules: accept / refuse /
  remove / leave / regenerate code / delete.
- **Accept:** normalisation table (`CS`, `CIS`, accents, case); permission matrix tests.

### [ ] T2.3 Firestore adapters
- `TourneeRepository` (create batch with `tourneeKeys` + `joinCodes`, request / accept / refuse,
  members stream, regenerate code), `StreetRepository` (snapshots with pending-writes metadata,
  `StreetChange` → field-path updates, soft delete, Corbeille query), mappers.
- **Accept:** `fake_cloud_firestore` tests: two concurrent marks on different houses both
  survive; mapping round-trips; duplicate tournée returns the right failure.

### [ ] T2.4 Security rules
- `firebase/firestore.rules` per PLAN §8.2 + emulator tests (`node --test`) + CI job.
- **Accept:** tests for every rule incl. the negative cases: pending member reads nothing,
  guessing `list` on `joinCodes` fails, `note` > 200 chars refused, `by` ≠ caller refused.

### [ ] T2.5 Onboarding screens
- Mockups `Welcome`, `Create`, `CreateTaken`, `Join`, `JoinPending`: name, CS picker with "Ajouter
  « … »", duplicate check as you type, QR + code + share, scan (`mobile_scanner`), code entry,
  preview, waiting screen that opens the tournée when accepted.
- **Accept:** widget tests for gating and the duplicate state; notifier tests for the join flow.

### [ ] T2.6 Équipe and Corbeille
- Mockups `Team`, `Trash`: QR + code, Partager, Nouveau code (creator), pending requests with
  Accepter / Refuser, members + Retirer (creator), Quitter / Supprimer, Corbeille with Restaurer;
  red dot on 👥.
- **Accept:** widget tests for pending accept and restore.

### [ ] T2.7 Mes tournées and Paramètres
- Mockups `Switcher`, `Settings` (without the offline section, added in T4.2): switch, create,
  join, my pending requests; name, theme, mes tournées, privacy, version, credits.
- **Accept:** switching changes the observed tournée; last tournée reopened at launch.

### [ ] T2.8 Street screen on Firestore
- Replace the on-phone adapter in `bootstrap/` with Firestore (keep the fake for tests); offer to
  move the reference area's streets and marks into the tournée; temporary street list until the
  map lands (T3.5).
- **Accept:** **[you]** two phones in the same tournée see each other's marks within seconds.

### [ ] T2.9 Pending-sync indicator
- "☁ N modifications en attente d'envoi" from snapshot metadata.
- **Accept:** notifier test with fake metadata; **[you]** visible in airplane mode after a mark.

---

## M3 — Map and streets

### [ ] T3.1 Geometry and map layers (domain)
- `GeoPoint`, `StreetShape`, Douglas–Peucker, polyline codec, `ProgressLevel`, map layers as
  plain data (lines with level, dots with status), tournée bounding box + margin.
- **Accept:** tables for simplification and codec round-trip; level per progress.

### [ ] T3.2 Address and shape adapters
- Extend `AddressDirectory` with geopf reverse + search (BAN lookup exists since T1.5); add
  `StreetShapes` (Overpass, with User-Agent) adapter with `MockClient` + fixtures captured from the real services.
- **Accept:** parsing tests on real fixtures; network errors map to a failure, not a crash.

### [ ] T3.3 Street-picking use cases
- `AddStreetFromMap` (point → BAN street → numbers with positions → shape → save),
  `AddManualStreet`, `TakeStreet`, `ReleaseStreet`, `SearchStreet`.
- **Accept:** use-case tests with fakes incl. "already in the tournée", "no BAN match",
  "offline".

### [ ] T3.4 Map widget
- `ui/map/`: MapLibre view with OpenFreeMap style, GeoJSON sources/layers from the domain's
  layers, tap → coordinates, locate me (`geolocator`, permission on first tap), attribution.
- **Accept:** layer-building code covered; **[you]** map renders and responds on your phone.

### [ ] T3.5 Accueil
- Mockups `Home`, `HomeZoom`: map with progress colours and legend, house dots from zoom 16,
  "Mes rues" panel (drag), Ajouter des rues button, title → Mes tournées, 👥 dot.
- **Accept:** widget tests on the panel; tapping a street opens it.

### [ ] T3.6 Ajouter des rues
- Mockups `Pick`, `Manual`: map mode, tapped road highlighted, street card in its four states,
  search box, "Saisir une rue à la main" (offline OK), "Connexion nécessaire" when offline.
- **Accept:** widget tests for the four card states; **[you]** add three real streets.

---

## M4 — Offline

### [ ] T4.1 Download the tournée
- Firestore unlimited cache; `DownloadTournee` use case (prefetch all street documents +
  offline map region of the bounding box, z12–17); `OfflineMapStore` adapter; progress and
  stored size/date.
- **Accept:** use-case tests with fakes (progress, failure, update, delete).

### [ ] T4.2 Offline in the UI
- Download banner on Accueil, Paramètres "Hors-ligne" section (Mettre à jour / Supprimer),
  disabled states (add from map, non-downloaded tournées greyed in Mes tournées).
- **Accept:** widget tests for each offline state.

### [ ] T4.3 Airplane-mode day  · **[you]**
- Run the device checklist of PLAN §11 (cold start offline, mark, restart, reconnect, sync,
  conflicts on the same house).
- **Accept:** checklist filled in `docs/spikes/offline-day.md`; bugs become tasks.

---

## M5 — Release (Android)

### [ ] T5.1 Dark mode and accessibility
- Dark tokens, TalkBack labels everywhere, 200 % font scale, contrast check.
- **Accept:** widget tests at 2.0 text scale on the street screen; **[you]** TalkBack pass.

### [ ] T5.2 Identity and store assets
- Launcher icon, splash, store name, privacy policy page, Play listing texts (French),
  screenshots from the real app.
- **Accept:** assets in `store/`; privacy policy published URL in Paramètres.

### [ ] T5.3 Signed release  · **[you]** for keys and Play Console
- Upload key, `key.properties` from env, `flutter build appbundle`, Play internal testing track.
- **Accept:** **[you]** install from the Play internal track.

---

## M6 — Next year (v1.1)

### [ ] T6.1 Roll-over rules (domain)
- Copy / reset rules, `previousStatus`, *Reprendre mes rues*, purge of campaign N-2.

### [ ] T6.2 StartCampaign
- Use case + Firestore batch + rules (creator only, previous campaign read-only).

### [ ] T6.3 Campaign UI
- Mockup `Campaign`, member banner, "En 2026 : …" in house and door sheets, archive read-only.

---

## M7 — iOS (when the Apple developer account exists)

### [ ] T7.1 iOS build in the cloud  · **[you]** for the Apple account
- `flutterfire configure` for iOS, App Attest, Codemagic (or macOS runner) workflow →
  TestFlight; iOS permissions texts (camera, location) in French.

### [ ] T7.2 iPhone pass  · **[you]**
- Run the device and airplane-mode checklists on an iPhone.

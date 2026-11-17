# Firestore security rules

- `firestore.rules`: who may read and write what (PLAN §8.2). They accept exactly what the
  Firestore adapters write (`lib/infrastructure/firestore/`) and refuse everything else.
- `firestore.indexes.json`: `houses` of the street documents is exempt from indexing.
- `firebase.json`: points the CLI at both files and configures the emulator.
- `test/`: the rules tests, run in the Firestore emulator. `support.mjs` holds documents
  shaped exactly as the Dart mappers write them: change both together.

```bash
cd firebase
npm ci        # once, and after a change of package-lock.json
npm test      # starts the emulator (demo project, no real data), runs test/*.test.mjs, stops it
```

The versions are pinned (firebase-tools 15, `@firebase/rules-unit-testing` 5, `firebase` 12) and
need Node 20 or later (22 locally and in CI) and Java 11 or later (the emulator is a Java
program, downloaded on the first run into `~/.cache/firebase/emulators`).
`@firebase/rules-unit-testing` 6 is not used: it needs Node 24.12 or later.

`overrides` in `package.json` lifts `@grpc/grpc-js` inside `@firebase/firestore` from 1.9 to the
1.14 line that firebase-tools already uses: 1.9 has known high-severity advisories. It also
lifts `@opentelemetry/core` (^2.8.0), `uuid` (^11.1.1), `glob` (^14.0.2) and `rimraf` (^6.1.4)
inside firebase-tools, whose published dependency ranges still pull versions with moderate
advisories (#102). firebase-tools forces the same versions in its own repository, but npm applies
`overrides` only from the top-level project, so they never reached this one. With them,
`npm audit` reports 0. If a firebase-tools upgrade breaks the emulators, suspect these first
(glob 10 → 14 under exegesis and archiver); drop each one once firebase-tools' own ranges cover it.

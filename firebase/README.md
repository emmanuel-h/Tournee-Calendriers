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

The versions are pinned to run on Node 18 or later and Java 11 or later (the emulator is a
Java program, downloaded on the first run into `~/.cache/firebase/emulators`).

// The shared index of the secteurs' parts (#133, PLAN §5.15, §6.2
// `streetParts/{banId}`, §8.2): FirestoreStreetPartIndex merges the open
// secteur's entry into the street's document (a `set` with `merge`),
// naming the secteur in `sector`; any signed-in phone reads one street by
// its BAN id.
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import {
  lea,
  manu,
  paul,
  phoneOf,
  rulesEnvironment,
  sam,
  sectorDoc,
  sectorId,
  sectorPath,
  seed,
  seedTeam,
  zoe,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-street-parts');
});

after(() => env.cleanup());

const partsPath = 'streetParts/69264_0420';

/** The entry of a secteur numbered [number] (entryOf in the mapper). */
const entry = (number, overrides = {}) => ({
  number,
  centreName: 'CS Villefranche',
  odd: 'all',
  even: 'all',
  ...overrides,
});

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
  // The secteur 12 of the same centre holds the odd side from 19 to 41.
  await seed(env, 'sectors/t12', sectorDoc({ number: 12 }));
  await seed(env, partsPath, {
    sector: 't12',
    parts: { t12: entry(12, { odd: [19, 41], even: 'none' }) },
  });
});

/** The index of Rue Nationale as stored, past the rules. */
async function storedParts() {
  let stored;
  await env.withSecurityRulesDisabled(async (context) => {
    stored = (await getDoc(doc(context.firestore(), partsPath))).data();
  });
  return stored;
}

const parts = (uid, path = partsPath) => doc(phoneOf(env, uid), path);

/** [uid] says the secteur [sector] holds [value] (heldPartWrite). */
const hold = (uid, value = entry(49), sector = sectorId, path = partsPath) =>
  setDoc(
    parts(uid, path),
    { sector, parts: { [sector]: value } },
    { merge: true },
  );

/** [uid] removes the entry of [sector] (releasedPartWrite). */
const release = (uid, sector = sectorId, path = partsPath) =>
  setDoc(
    parts(uid, path),
    { sector, parts: { [sector]: deleteField() } },
    { merge: true },
  );

describe('reading the index', () => {
  it('should let any signed-in phone read a street by its id', async () => {
    await assertSucceeds(getDoc(parts(zoe)));
    await assertSucceeds(getDoc(parts(paul)));
    await assertSucceeds(getDoc(parts(lea, 'streetParts/69264_9999')));
  });

  it('should refuse no sign-in, and listing to anyone', async () => {
    await assertFails(getDoc(parts(null)));
    await assertFails(getDocs(collection(phoneOf(env, lea), 'streetParts')));
    await assertFails(getDocs(collection(phoneOf(env, manu), 'streetParts')));
  });
});

describe('holding a part', () => {
  it('should let an active member write their secteur\'s entry, keeping the others', async () => {
    await assertSucceeds(hold(lea));
    await assertSucceeds(hold(lea, entry(49, { odd: 'none', even: [2, 30] })));
    const stored = await storedParts();
    if (Object.keys(stored.parts).sort().join() !== 't12,t49') {
      throw new Error(`Entries lost: ${JSON.stringify(stored)}`);
    }
  });

  it('should let an active member create the document of a new street', async () => {
    await assertSucceeds(hold(lea, entry(49), sectorId, 'streetParts/69264_0610'));
  });

  it('should let an admin outside the team write the secteur\'s entry', async () => {
    await assertSucceeds(hold(sam));
  });

  it('should refuse a pending member, someone outside, and no sign-in', async () => {
    await assertFails(hold(paul));
    await assertFails(hold(zoe));
    await assertFails(hold(null));
  });

  it('should refuse the entry of a secteur the caller is not in', async () => {
    await assertFails(hold(lea, entry(12), 't12'));
  });

  it('should refuse another number or centre than the secteur\'s', async () => {
    await assertFails(hold(lea, entry(12)));
    await assertFails(hold(lea, entry(49, { centreName: 'CS Arnas' })));
  });

  it('should refuse sides not shaped as a part', async () => {
    await assertFails(hold(lea, entry(49, { odd: [2, 8] })));
    await assertFails(hold(lea, entry(49, { even: [1, 7] })));
    await assertFails(hold(lea, entry(49, { odd: [41, 19] })));
    await assertFails(hold(lea, entry(49, { odd: 'some' })));
  });

  it('should refuse an entry with a field more or less', async () => {
    await assertFails(hold(lea, entry(49, { by: lea })));
    const { even, ...noEven } = entry(49);
    await assertFails(
      setDoc(parts(lea), { sector: sectorId, parts: { [sectorId]: noEven } }),
    );
  });

  it('should refuse a write naming another secteur than the entry it changes', async () => {
    await assertFails(
      setDoc(
        parts(lea),
        { sector: sectorId, parts: { t12: entry(12, { odd: 'all' }) } },
        { merge: true },
      ),
    );
  });

  it('should refuse a write changing two entries', async () => {
    await assertFails(
      setDoc(parts(lea), { sector: sectorId, parts: { [sectorId]: entry(49) } }),
    );
  });

  it('should refuse a field more on the document, or a bad secteur id', async () => {
    await assertFails(
      setDoc(
        parts(lea),
        { sector: sectorId, parts: { [sectorId]: entry(49) }, note: 'x' },
        { merge: true },
      ),
    );
    await assertFails(
      updateDoc(parts(lea), { sector: 't-49', 'parts.t-49': entry(49) }),
    );
  });
});

describe('releasing a part', () => {
  beforeEach(async () => {
    await seed(env, partsPath, {
      sector: sectorId,
      parts: { t12: entry(12, { odd: [19, 41], even: 'none' }), [sectorId]: entry(49) },
    });
  });

  it('should let an active member remove their secteur\'s entry, and only it', async () => {
    await assertSucceeds(release(lea));
    const stored = await storedParts();
    if (Object.keys(stored.parts).join() !== 't12') {
      throw new Error(`Wrong entries: ${JSON.stringify(stored)}`);
    }
  });

  it('should let an admin remove a deleted secteur\'s entry', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), sectorPath)),
    );
    await assertSucceeds(release(sam));
    await assertFails(release(zoe));
  });

  it('should let a member remove an entry that is not there', async () => {
    await assertSucceeds(release(lea, sectorId, 'streetParts/69264_0610'));
  });

  it('should refuse a new document naming no secteur, or with parts not a map', async () => {
    await assertFails(
      setDoc(
        parts(lea, 'streetParts/69264_0610'),
        { parts: { [sectorId]: entry(49) } },
        { merge: true },
      ),
    );
    await assertFails(
      setDoc(parts(lea, 'streetParts/69264_0610'), { sector: sectorId, parts: 'all' }),
    );
  });

  it('should refuse removing another secteur\'s entry', async () => {
    await assertFails(release(lea, 't12'));
    await assertFails(release(zoe, 't12'));
  });

  it('should never let the document be deleted', async () => {
    await assertFails(deleteDoc(parts(lea)));
    await assertFails(deleteDoc(parts(sam)));
  });
});

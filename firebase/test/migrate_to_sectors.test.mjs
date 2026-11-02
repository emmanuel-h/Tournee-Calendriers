// The one-off migration to the names of #116 (tool/migrate_to_sectors.mjs),
// run on the emulator `firebase emulators:exec` started: a small tournée of
// 0.9.0 (team, campaign, one street, its key and its join code) is copied,
// copied again, then the old names are deleted.
import { after, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { deleteApp, initializeApp } from 'firebase-admin/app';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { migrate, renamed, renamedFields, report } from '../tool/migrate_to_sectors.mjs';

// Its own project: `node --test` runs the files at the same time.
const projectId = 'demo-migration';
const app = initializeApp({ projectId }, 'migration-test');
const db = getFirestore(app);
const twoPm = Timestamp.fromDate(new Date('2026-11-02T14:00:00Z'));

const sector = { number: 49, centreKey: 'villefranche', currentCampaign: 2026, joinCode: 'K7M2QX' };
const member = { name: 'Léa', status: 'active', joinedAt: twoPm };
const street = {
  name: 'Rue Nationale',
  houses: { 12: { status: 'visited', changedAt: twoPm }, '12B': { status: 'todo' } },
};
const joinCode = { tourneeId: 't49', number: 49, centreName: 'CS Villefranche', campaign: 2026 };

async function seedVersion09() {
  await db.doc('tournees/t49').set(sector);
  await db.doc('tournees/t49/members/lea').set(member);
  await db.doc('tournees/t49/campaigns/2026').set({ year: 2026 });
  await db.doc('tournees/t49/campaigns/2026/streets/s1').set(street);
  await db.doc('tourneeKeys/villefranche_49').set({ tourneeId: 't49' });
  await db.doc('joinCodes/K7M2QX').set(joinCode);
}

const dataAt = async (path) => (await db.doc(path).get()).data();

beforeEach(async () => {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  await fetch(`http://${host}/emulator/v1/projects/${projectId}/databases/(default)/documents`, {
    method: 'DELETE',
  });
  await seedVersion09();
});

after(() => deleteApp(app));

describe('names', () => {
  test('should rename what says tournee, whatever its case', () => {
    assert.equal(renamed('tournees'), 'sectors');
    assert.equal(renamed('tourneeKeys'), 'sectorKeys');
    assert.equal(renamed('tourneeId'), 'sectorId');
    assert.equal(renamed('lastTourneeOpened'), 'lastSectorOpened');
    assert.equal(renamed('members'), 'members');
  });

  test('should rename only the top-level fields, keeping every value', () => {
    assert.deepEqual(renamedFields({ tourneeId: 't49', houses: { tourneeId: 'x' } }), {
      sectorId: 't49',
      houses: { tourneeId: 'x' },
    });
  });
});

describe('dry run', () => {
  test('should count what it would copy and write nothing', async () => {
    const counts = await migrate(db);

    assert.deepEqual(counts, {
      sectors: { toCopy: 4, alreadyThere: 0, toDelete: 4 },
      sectorKeys: { toCopy: 1, alreadyThere: 0, toDelete: 1 },
      joinCodes: { toCopy: 1, alreadyThere: 0, toDelete: 1 },
    });
    assert.equal((await db.collection('sectors').listDocuments()).length, 0);
    assert.equal((await db.collection('sectorKeys').get()).size, 0);
    assert.deepEqual(await dataAt('joinCodes/K7M2QX'), joinCode);
  });
});

describe('--apply', () => {
  test('should copy the whole tree of each tournée to sectors/', async () => {
    await migrate(db, { apply: true });

    assert.deepEqual(await dataAt('sectors/t49'), sector);
    assert.deepEqual(await dataAt('sectors/t49/members/lea'), member);
    assert.deepEqual(await dataAt('sectors/t49/campaigns/2026'), { year: 2026 });
    assert.deepEqual(await dataAt('sectors/t49/campaigns/2026/streets/s1'), street);
  });

  test('should copy each key to sectorKeys/ with its field renamed', async () => {
    await migrate(db, { apply: true });

    assert.deepEqual(await dataAt('sectorKeys/villefranche_49'), { sectorId: 't49' });
  });

  test('should add sectorId to each join code, the old field beside it', async () => {
    await migrate(db, { apply: true });

    assert.deepEqual(await dataAt('joinCodes/K7M2QX'), { ...joinCode, sectorId: 't49' });
  });

  test('should keep every old document', async () => {
    await migrate(db, { apply: true });

    assert.deepEqual(await dataAt('tournees/t49/campaigns/2026/streets/s1'), street);
    assert.deepEqual(await dataAt('tourneeKeys/villefranche_49'), { tourneeId: 't49' });
  });

  test('should count everything as already there when run again', async () => {
    await migrate(db, { apply: true });
    const counts = await migrate(db, { apply: true });

    assert.deepEqual(counts, {
      sectors: { toCopy: 0, alreadyThere: 4, toDelete: 4 },
      sectorKeys: { toCopy: 0, alreadyThere: 1, toDelete: 1 },
      joinCodes: { toCopy: 0, alreadyThere: 1, toDelete: 1 },
    });
  });

  test('should never overwrite what the app changed since the first run', async () => {
    await migrate(db, { apply: true });
    await db.doc('sectors/t49/campaigns/2026/streets/s1').update({ 'houses.12B.status': 'visited' });
    await migrate(db, { apply: true });

    const copy = await dataAt('sectors/t49/campaigns/2026/streets/s1');
    assert.equal(copy.houses['12B'].status, 'visited');
  });

  test('should copy a document added under an old tournée after the first run', async () => {
    await migrate(db, { apply: true });
    await db.doc('tournees/t49/members/hugo').set({ ...member, name: 'Hugo' });
    const counts = await migrate(db, { apply: true });

    assert.equal(counts.sectors.toCopy, 1);
    assert.equal((await dataAt('sectors/t49/members/hugo')).name, 'Hugo');
  });

  test('should leave alone a join code with no old field', async () => {
    await db.doc('joinCodes/AB3CD4').set({ ...renamedFields(joinCode), number: 12 });
    const counts = await migrate(db, { apply: true });

    assert.equal(counts.joinCodes.toCopy, 1);
    assert.equal(counts.joinCodes.toDelete, 1);
    assert.equal((await dataAt('joinCodes/AB3CD4')).number, 12);
  });
});

describe('--delete-old', () => {
  test('should copy first, then delete the old tree, keys and fields', async () => {
    const counts = await migrate(db, { deleteOld: true });

    assert.equal(counts.sectors.toCopy, 4);
    assert.deepEqual(await dataAt('sectors/t49/campaigns/2026/streets/s1'), street);
    assert.equal((await db.collection('tournees').listDocuments()).length, 0);
    assert.equal((await db.collection('tourneeKeys').get()).size, 0);
    assert.deepEqual(await dataAt('sectorKeys/villefranche_49'), { sectorId: 't49' });
    assert.deepEqual(await dataAt('joinCodes/K7M2QX'), renamedFields(joinCode));
  });

  test('should find nothing left to do when run again', async () => {
    await migrate(db, { deleteOld: true });
    const counts = await migrate(db, { deleteOld: true });

    assert.deepEqual(counts, {
      sectors: { toCopy: 0, alreadyThere: 0, toDelete: 0 },
      sectorKeys: { toCopy: 0, alreadyThere: 0, toDelete: 0 },
      joinCodes: { toCopy: 0, alreadyThere: 0, toDelete: 0 },
    });
  });
});

describe('report', () => {
  const counts = { sectors: { toCopy: 4, alreadyThere: 2, toDelete: 6 } };

  test('should say what a dry run would copy', () => {
    assert.deepEqual(report(counts, 'dry-run'), [
      'sectors: 4 to copy, 2 already there, 6 old to delete with --delete-old',
    ]);
  });

  test('should say what --apply copied', () => {
    assert.deepEqual(report(counts, 'apply'), [
      'sectors: 4 copied, 2 already there, 6 old to delete with --delete-old',
    ]);
  });

  test('should say what --delete-old deleted', () => {
    assert.deepEqual(report(counts, 'delete-old'), [
      'sectors: 4 copied, 2 already there, 6 old deleted',
    ]);
  });
});

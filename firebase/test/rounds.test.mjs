// The validated tournées of a campaign (#63, PLAN §6.2, « Tournées » in
// §8.2): FirestoreRoundLedger creates one document per tournée, with no
// member in it, and nobody changes or deletes it afterwards (only the
// deletion of the secteur, sectors.test.mjs).
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import {
  at,
  campaignDoc,
  lea,
  manu,
  memberPath,
  paul,
  phoneOf,
  roundDoc,
  roundsPath,
  rulesEnvironment,
  sectorDoc,
  sam,
  sectorPath,
  seed,
  seedTeam,
  zoe,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-rounds');
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
});

/** The tournée [id] of the campaign 2026, as [uid]'s phone sees it. */
const round = (uid, id = 'Ab12Cd34Ef56Gh78Ij90') =>
  doc(phoneOf(env, uid), `${roundsPath}/${id}`);

/** [uid] records a tournée as the adapter does: a `set` of the summary. */
const record = (uid, data = roundDoc(), id = undefined) => setDoc(round(uid, id), data);

describe('reading the validated tournées', () => {
  it('should let an active member and an admin read and list them', async () => {
    await assertSucceeds(getDoc(round(lea, 'round1')));
    await assertSucceeds(getDocs(collection(phoneOf(env, lea), roundsPath)));
    await assertSucceeds(getDocs(collection(phoneOf(env, manu), roundsPath)));
    await assertSucceeds(getDocs(collection(phoneOf(env, sam), roundsPath)));
  });

  it('should refuse a pending member, someone outside, and no sign-in', async () => {
    await assertFails(getDocs(collection(phoneOf(env, paul), roundsPath)));
    await assertFails(getDoc(round(zoe, 'round1')));
    await assertFails(getDocs(collection(phoneOf(env, null), roundsPath)));
  });
});

describe('recording a validated tournée', () => {
  it('should let an active member create one', async () => {
    await assertSucceeds(record(lea));
    await assertSucceeds(record(manu, roundDoc(), 'Zz99'));
  });

  it('should refuse a pending member, someone outside, and no sign-in', async () => {
    await assertFails(record(paul));
    await assertFails(record(zoe));
    await assertFails(record(null));
  });

  it('should refuse an admin who is not a member: a visit runs no tournée', async () => {
    await assertFails(record(sam));
  });

  it('should refuse a member removed before the write reached the server', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), memberPath(lea))),
    );

    await assertFails(record(lea));
  });

  it('should refuse a campaign that does not exist', async () => {
    await assertFails(
      setDoc(doc(phoneOf(env, lea), `${sectorPath}/campaigns/2027/rounds/Ab12`), roundDoc()),
    );
  });

  it('should refuse a campaign that exists but is not the secteur\'s current one (#145)', async () => {
    // A past campaign, still stored: its tournées are over.
    await seed(env, `${sectorPath}/campaigns/2025`, campaignDoc());

    await assertFails(
      setDoc(doc(phoneOf(env, lea), `${sectorPath}/campaigns/2025/rounds/Ab12`), roundDoc()),
    );
  });

  it('should accept the current campaign once the secteur moved on to it (#145)', async () => {
    await seed(env, `${sectorPath}/campaigns/2027`, campaignDoc());
    await seed(env, sectorPath, sectorDoc({ currentCampaign: 2027 }));

    await assertSucceeds(
      setDoc(doc(phoneOf(env, lea), `${sectorPath}/campaigns/2027/rounds/Ab12`), roundDoc()),
    );
    await assertFails(record(lea));
  });

  it('should refuse an id the app does not make', async () => {
    await assertFails(record(lea, roundDoc(), 'round-1'));
  });

  for (const field of Object.keys(roundDoc())) {
    it(`should refuse a summary without ${field}`, async () => {
      const data = roundDoc();
      delete data[field];
      await assertFails(record(lea, data));
    });
  }

  it('should refuse any other field, a member first of all', async () => {
    await assertFails(record(lea, roundDoc({ by: lea })));
    await assertFails(record(lea, roundDoc({ member: lea })));
    await assertFails(record(lea, roundDoc({ donations: [] })));
  });

  it('should accept a tournée ending one second after it started, and nothing earlier', async () => {
    const startedAt = at('2026-10-24T12:05:00Z');
    await assertSucceeds(
      record(lea, roundDoc({ startedAt, endedAt: at('2026-10-24T12:05:01Z') })),
    );
    await assertFails(record(lea, roundDoc({ startedAt, endedAt: startedAt }), 'Same'));
    await assertFails(
      record(lea, roundDoc({ startedAt, endedAt: at('2026-10-24T12:04:59Z') }), 'Before'),
    );
  });

  it('should refuse times that are not timestamps', async () => {
    await assertFails(record(lea, roundDoc({ startedAt: '2026-10-24T12:05:00Z' })));
    await assertFails(record(lea, roundDoc({ endedAt: 1761307200 })));
  });

  for (const field of ['housesVisited', 'free']) {
    it(`should accept ${field} from 0 to 9 999, and refuse the rest`, async () => {
      await assertSucceeds(record(lea, roundDoc({ [field]: 0 }), 'Zero'));
      await assertSucceeds(record(lea, roundDoc({ [field]: 9999 }), 'Most'));
      await assertFails(record(lea, roundDoc({ [field]: 10000 })));
      await assertFails(record(lea, roundDoc({ [field]: -1 })));
      await assertFails(record(lea, roundDoc({ [field]: 1.5 })));
      await assertFails(record(lea, roundDoc({ [field]: '23' })));
    });
  }

  for (const method of ['cash', 'cheque', 'card']) {
    it(`should accept a ${method} total of 0–9 999 dons and 0–100 000 000 cents`, async () => {
      await assertSucceeds(
        record(lea, roundDoc({ [method]: { count: 0, cents: 0 } }), 'Zero'),
      );
      await assertSucceeds(
        record(lea, roundDoc({ [method]: { count: 9999, cents: 100000000 } }), 'Most'),
      );
    });

    it(`should refuse a ${method} total out of its bounds or not as written`, async () => {
      for (const total of [
        { count: 10000, cents: 0 },
        { count: -1, cents: 0 },
        { count: 0, cents: 100000001 },
        { count: 0, cents: -1 },
        { count: 1, cents: 10.5 },
        { count: 1 },
        { cents: 1000 },
        { count: 1, cents: 1000, by: lea },
        1000,
      ]) {
        await assertFails(record(lea, roundDoc({ [method]: total })));
      }
    });
  }
});

describe('a validated tournée afterwards', () => {
  it('should refuse sending it again: the first one stays', async () => {
    await assertFails(record(lea, roundDoc({ housesVisited: 24 }), 'round1'));
    await assertFails(record(lea, roundDoc(), 'round1'));
  });

  it('should refuse any change, even by an admin', async () => {
    await assertFails(updateDoc(round(lea, 'round1'), { housesVisited: 24 }));
    await assertFails(updateDoc(round(manu, 'round1'), { free: 0 }));
    await assertFails(updateDoc(round(sam, 'round1'), { free: 0 }));
  });

  it('should refuse a member deleting it', async () => {
    await assertFails(deleteDoc(round(lea, 'round1')));
    await assertFails(deleteDoc(round(zoe, 'round1')));
  });

  it('should let an admin delete it, as the deletion of the secteur does', async () => {
    await assertSucceeds(deleteDoc(round(sam, 'round1')));
  });
});

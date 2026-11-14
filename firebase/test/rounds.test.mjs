// The validated tournées of a campaign (#63, PLAN §6.2, « Tournées » in
// §8.2): FirestoreRoundLedger creates one document per tournée, with no
// member in it and its dons (#168); afterwards only a correction or a
// forgotten house settled changes it (#168, PLAN §5.20), and only the
// deletion of the secteur deletes it (sectors.test.mjs).
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  increment,
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
  roundDons,
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

  it('should refuse a correction sent with the summary (#168)', async () => {
    await assertFails(record(lea, roundDoc({ correctedAt: at('2026-10-25T09:00:00Z') })));
    await assertFails(record(lea, roundDoc({ housesToMark: 0 })));
  });

  it('should accept an empty list of dons, and up to 2 000 (#168)', async () => {
    await assertSucceeds(record(lea, roundDoc({ dons: [] }), 'None'));
    await assertSucceeds(
      record(lea, roundDoc({ dons: Array(2000).fill('free') }), 'Most'),
    );
    await assertFails(record(lea, roundDoc({ dons: Array(2001).fill('free') })));
  });

  it('should accept each method from 1 to 100 000 cents, and a free calendar', async () => {
    await assertSucceeds(
      record(
        lea,
        roundDoc({ dons: ['cash:1', 'cheque:750', 'card:100000', 'cash:99999', 'free'] }),
        'Each',
      ),
    );
  });

  it('should refuse a don it cannot read, whatever its place', async () => {
    for (const don of [
      'cash:0',
      'cash:100001',
      'cash:007',
      'cash:-5',
      'cash:7.5',
      'cash:',
      'cash',
      'gold:1000',
      'Cash:1000',
      'free:1',
      ' free',
      '',
      1000,
      { method: 'cash', cents: 1000 },
      null,
    ]) {
      await assertFails(record(lea, roundDoc({ dons: [don] })), `${don}`);
      await assertFails(record(lea, roundDoc({ dons: ['free', 'cash:500', don] })), `${don}`);
    }
  });

  it('should refuse two dons hidden in one entry', async () => {
    await assertFails(record(lea, roundDoc({ dons: ['cash:500,cash:700'] })));
    await assertFails(record(lea, roundDoc({ dons: ['free', 'free,free'] })));
  });

  it('should refuse dons that are not a list', async () => {
    await assertFails(record(lea, roundDoc({ dons: 'cash:500' })));
    await assertFails(record(lea, roundDoc({ dons: { 0: 'cash:500' } })));
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

    it(`should accept a ${method} total of 1 000 € a don, and refuse a cent more`, async () => {
      await assertSucceeds(
        record(lea, roundDoc({ [method]: { count: 3, cents: 300000 } }), 'Avg'),
      );
      await assertFails(record(lea, roundDoc({ [method]: { count: 3, cents: 300001 } })));
    });

    it(`should refuse a ${method} total of dons without money, or money without a don`, async () => {
      await assertFails(record(lea, roundDoc({ [method]: { count: 8, cents: 0 } })));
      await assertFails(record(lea, roundDoc({ [method]: { count: 0, cents: 2000 } })));
      await assertSucceeds(record(lea, roundDoc({ [method]: { count: 1, cents: 1 } }), 'One'));
    });

    it(`should refuse a ${method} total out of its bounds or not as written`, async () => {
      for (const total of [
        { count: 10000, cents: 10000 },
        { count: -1, cents: 0 },
        { count: 9999, cents: 100000001 },
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

  it('should refuse a change that is not a correction, even by an admin', async () => {
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

/** When the tournée was corrected, the phone's clock. */
const correctedAt = at('2026-10-25T09:00:00Z');

/**
 * A correction as FirestoreRoundLedger writes it (`correctionToUpdate`):
 * the totals, the list when it changed, the time, the houses it adds as
 * an increment.
 */
const correction = (overrides = {}) => ({
  free: 2,
  cash: { count: 15, cents: 21000 },
  cheque: { count: 3, cents: 6000 },
  card: { count: 2, cents: 1500 },
  dons: [...roundDons(), 'card:500'],
  correctedAt,
  housesToMark: increment(1),
  ...overrides,
});

/** [uid] corrects the tournée round1. */
const correct = (uid, data = correction()) => updateDoc(round(uid, 'round1'), data);

/** The tournée round1 as stored, read without the rules. */
async function stored() {
  let data;
  await env.withSecurityRulesDisabled(async (context) => {
    data = (await getDoc(doc(context.firestore(), `${roundsPath}/round1`))).data();
  });
  return data;
}

describe('correcting a validated tournée (#168)', () => {
  it('should let an active member and an admin correct it', async () => {
    await assertSucceeds(correct(lea));
    await assertSucceeds(correct(manu, correction({ correctedAt: at('2026-10-25T10:00:00Z') })));
    await assertSucceeds(correct(sam, correction({ correctedAt: at('2026-10-25T11:00:00Z') })));

    const data = await stored();
    assert.deepEqual(data.housesToMark, 3);
    assert.deepEqual(data.card, { count: 2, cents: 1500 });
    assert.deepEqual(data.housesVisited, 23);
  });

  it('should refuse a pending member, someone outside, and no sign-in', async () => {
    await assertFails(correct(paul));
    await assertFails(correct(zoe));
    await assertFails(correct(null));
  });

  it('should accept the totals alone, the list left as it is', async () => {
    const { dons, ...totalsOnly } = correction();
    await assertSucceeds(correct(lea, totalsOnly));
    assert.deepEqual((await stored()).dons, roundDons());
  });

  it('should refuse a correction without its time, or a time that is not one', async () => {
    const { correctedAt: _, ...untimed } = correction();
    await assertFails(correct(lea, untimed));
    await assertFails(correct(lea, correction({ correctedAt: '2026-10-25' })));
  });

  for (const [field, value] of [
    ['startedAt', at('2026-10-24T11:00:00Z')],
    ['endedAt', at('2026-10-24T17:00:00Z')],
    ['housesVisited', 24],
  ]) {
    it(`should refuse a correction changing ${field}`, async () => {
      await assertFails(correct(lea, correction({ [field]: value })));
    });
  }

  it('should refuse removing the list of dons', async () => {
    await assertFails(correct(lea, correction({ dons: deleteField() })));
  });

  it('should refuse giving a list to a tournée validated without one', async () => {
    const { dons, ...before168 } = roundDoc();
    await seed(env, `${roundsPath}/round1`, before168);

    await assertFails(correct(lea));
    const { dons: _, ...totalsOnly } = correction();
    await assertSucceeds(correct(lea, totalsOnly));
  });

  it('should refuse a list of dons it cannot read', async () => {
    await assertFails(correct(lea, correction({ dons: ['cash:0'] })));
    await assertFails(correct(lea, correction({ dons: ['cash:500,free'] })));
    await assertFails(correct(lea, correction({ dons: Array(2001).fill('free') })));
  });

  it('should refuse totals out of the bounds of a summary', async () => {
    await assertFails(correct(lea, correction({ cheque: { count: 0, cents: 2000 } })));
    await assertFails(correct(lea, correction({ cheque: { count: 8, cents: 0 } })));
    await assertFails(correct(lea, correction({ cheque: { count: 1, cents: 100001 } })));
    await assertFails(correct(lea, correction({ free: 10000 })));
    await assertFails(correct(lea, correction({ cash: { count: 10000, cents: 10000 } })));
  });

  it('should keep the houses to mark within 0–9 999', async () => {
    await assertSucceeds(correct(lea, correction({ housesToMark: 9999 })));
    await assertFails(
      correct(lea, correction({ housesToMark: 10000, correctedAt: at('2026-10-25T10:00:00Z') })),
    );
    const later = at('2026-10-25T12:00:00Z');
    await assertFails(correct(lea, correction({ housesToMark: -1, correctedAt: later })));
    await assertFails(correct(lea, correction({ housesToMark: '1', correctedAt: later })));
  });

  it('should refuse a second correction keeping the time of the first', async () => {
    await assertSucceeds(correct(lea));

    await assertFails(correct(lea, correction({ free: 3 })));
    await assertSucceeds(
      correct(lea, correction({ free: 3, correctedAt: at('2026-10-25T10:00:00Z') })),
    );
  });

  it('should refuse any other field, a member first of all', async () => {
    await assertFails(correct(lea, correction({ by: lea })));
    await assertFails(correct(lea, correction({ member: lea })));
  });

  it('should refuse a correction in a past campaign', async () => {
    await seed(env, `${sectorPath}/campaigns/2027`, campaignDoc());
    await seed(env, sectorPath, sectorDoc({ currentCampaign: 2027 }));

    await assertFails(correct(lea));
  });

  it('should still refuse the summary sent again once corrected: it would wipe the correction', async () => {
    await assertSucceeds(correct(lea));

    await assertFails(record(lea, roundDoc(), 'round1'));
    assert.ok((await stored()).correctedAt.isEqual(correctedAt));
  });
});

describe('a forgotten house marked or ignored (#168)', () => {
  beforeEach(async () => {
    await seed(env, `${roundsPath}/round1`, roundDoc({ correctedAt, housesToMark: 2 }));
  });

  /** [uid] settles a house as the adapter does (`forgottenHouseToUpdate`). */
  const settle = (uid, { marked }) =>
    updateDoc(
      round(uid, 'round1'),
      marked
        ? { housesToMark: increment(-1), housesVisited: increment(1) }
        : { housesToMark: increment(-1) },
    );

  it('should let an active member and an admin mark one, one more house visited', async () => {
    await assertSucceeds(settle(lea, { marked: true }));
    await assertSucceeds(settle(sam, { marked: true }));

    const data = await stored();
    assert.deepEqual(data.housesToMark, 0);
    assert.deepEqual(data.housesVisited, 25);
  });

  it('should let them ignore one, nothing else changed', async () => {
    await assertSucceeds(settle(manu, { marked: false }));

    const data = await stored();
    assert.deepEqual(data.housesToMark, 1);
    assert.deepEqual(data.housesVisited, 23);
  });

  it('should refuse a pending member, someone outside, and no sign-in', async () => {
    await assertFails(settle(paul, { marked: true }));
    await assertFails(settle(zoe, { marked: false }));
    await assertFails(settle(null, { marked: false }));
  });

  it('should refuse one more than there is to mark', async () => {
    await assertSucceeds(settle(lea, { marked: false }));
    await assertSucceeds(settle(lea, { marked: true }));

    await assertFails(settle(lea, { marked: false }));
    await assertFails(settle(lea, { marked: true }));
  });

  it('should refuse a tournée with no house to mark', async () => {
    await seed(env, `${roundsPath}/round1`, roundDoc());

    await assertFails(settle(lea, { marked: false }));
  });

  it('should refuse two at once, or houses visited without one fewer to mark', async () => {
    await assertFails(updateDoc(round(lea, 'round1'), { housesToMark: increment(-2) }));
    await assertFails(
      updateDoc(round(lea, 'round1'), {
        housesToMark: increment(-1),
        housesVisited: increment(2),
      }),
    );
    await assertFails(
      updateDoc(round(lea, 'round1'), {
        housesToMark: increment(-1),
        housesVisited: increment(-1),
      }),
    );
    await assertFails(updateDoc(round(lea, 'round1'), { housesVisited: increment(1) }));
  });

  it('should refuse anything else changed with it', async () => {
    await assertFails(
      updateDoc(round(lea, 'round1'), { housesToMark: increment(-1), free: 3 }),
    );
    await assertFails(
      updateDoc(round(lea, 'round1'), { housesToMark: increment(-1), dons: [] }),
    );
  });

  it('should still refuse the summary sent again', async () => {
    await assertFails(record(lea, roundDoc(), 'round1'));
    await assertFails(record(lea, roundDoc({ housesToMark: 1 }), 'round1'));
  });
});

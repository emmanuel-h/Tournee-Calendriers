// A new campaign (#39, PLAN §5.10, « A new campaign » in §8.2), as
// FirestoreCampaignStore writes it for an admin: the later campaign's
// document and the copies of the current streets (a few per batch), then
// `currentCampaign` moved forward with the join preview, then the past
// years no longer kept deleted. The year left is frozen for everyone.
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import {
  at,
  campaignDoc,
  code,
  houseEntry,
  lea,
  manu,
  phoneOf,
  previewDoc,
  roundDoc,
  roundsPath,
  rulesEnvironment,
  sam,
  sectorDoc,
  sectorPath,
  seed,
  seedTeam,
  streetDoc,
  streetsPath,
  threePm,
  updateFields,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-campaigns');
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
});

const next = `${sectorPath}/campaigns/2027`;
const nextStreets = `${next}/streets`;

/** nextCampaignDocument: the campaign 2027, copied from 2026. */
const nextCampaignDoc = (overrides = {}) => ({
  startedAt: at('2027-09-01T08:00:00Z'),
  previousYear: 2026,
  ...overrides,
});

/**
 * streetToDocument of Rue Nationale's copy (`Street.forNextCampaign`):
 * the same street, every shown number to do and unstamped, the building
 * laid out the same with its doors to do, the numbers of the Corbeille
 * (14, 14ter) left behind.
 */
const copyDoc = (overrides = {}) => {
  const source = streetDoc();
  return {
    ...source,
    houses: {
      4: houseEntry(4),
      '4bis': houseEntry(4, { sfx: 'bis' }),
      6: houseEntry(6),
      8: {
        ...source.houses[8],
        dwellings: {
          'A0-Gauche': { status: 'TO_DO', comeBack: null, by: null, at: null },
          'A0-Porte 1.2': { status: 'TO_DO', comeBack: null, by: null, at: null },
        },
      },
    },
    ...overrides,
  };
};

/**
 * [uid] writes the campaign 2027 (unless [withCampaign] is false) and the
 * copies [copies] (`{ id: document }`) in one batch, as the adapter's
 * first batch does.
 */
function writeCopies(uid, copies = { nationale: copyDoc() }, { withCampaign = true, year = '2027' } = {}) {
  const db = phoneOf(env, uid);
  const batch = writeBatch(db);
  if (withCampaign) batch.set(doc(db, `${sectorPath}/campaigns/${year}`), nextCampaignDoc());
  for (const [id, data] of Object.entries(copies)) {
    batch.set(doc(db, `${sectorPath}/campaigns/${year}/streets/${id}`), data);
  }
  return batch.commit();
}

/**
 * [uid] moves the secteur to [year] with its join preview in one batch,
 * as the adapter's transaction does (unless [withPreview] is false).
 */
function startCampaign(uid, year = 2027, { withPreview = true } = {}) {
  const db = phoneOf(env, uid);
  const batch = writeBatch(db);
  batch.update(doc(db, sectorPath), { currentCampaign: year });
  if (withPreview) batch.update(doc(db, `joinCodes/${code}`), { campaign: year });
  return batch.commit();
}

describe('a later campaign', () => {
  it('should let an admin, member or not, create the next year copied from the current one', async () => {
    await assertSucceeds(setDoc(doc(phoneOf(env, sam), next), nextCampaignDoc()));
    await assertSucceeds(
      setDoc(doc(phoneOf(env, manu), `${sectorPath}/campaigns/2028`), nextCampaignDoc()),
    );
  });

  it('should refuse a member who is not an admin', async () => {
    await assertFails(setDoc(doc(phoneOf(env, lea), next), nextCampaignDoc()));
  });

  it('should refuse a year that is not after the current one', async () => {
    await seed(env, `${sectorPath}/campaigns/2026`, campaignDoc());
    await assertFails(
      setDoc(doc(phoneOf(env, sam), `${sectorPath}/campaigns/2025`), nextCampaignDoc()),
    );
    await assertFails(
      setDoc(doc(phoneOf(env, sam), `${sectorPath}/campaigns/2026`), nextCampaignDoc()),
    );
  });

  it('should refuse an id that is not a year', async () => {
    await assertFails(
      setDoc(doc(phoneOf(env, sam), `${sectorPath}/campaigns/next`), nextCampaignDoc()),
    );
    await assertFails(
      setDoc(doc(phoneOf(env, sam), `${sectorPath}/campaigns/20270`), nextCampaignDoc()),
    );
  });

  it('should refuse a previous year that is not the current one, a start that is no time, another field', async () => {
    for (const data of [
      nextCampaignDoc({ previousYear: null }),
      nextCampaignDoc({ previousYear: 2025 }),
      nextCampaignDoc({ startedAt: '2027-09-01' }),
      nextCampaignDoc({ streets: 60 }),
    ]) {
      await assertFails(setDoc(doc(phoneOf(env, sam), next), data));
    }
  });
});

describe('copying the streets', () => {
  it('should let an admin copy a street of the current campaign with the new campaign', async () => {
    await assertSucceeds(writeCopies(sam));
  });

  it('should let an admin copy into a campaign written before, and copy a street again', async () => {
    await assertSucceeds(writeCopies(sam));

    await assertSucceeds(writeCopies(manu, { nationale: copyDoc() }, { withCampaign: false }));
  });

  it('should refuse a copy without its campaign, or by a member who is not an admin', async () => {
    await assertFails(writeCopies(sam, { nationale: copyDoc() }, { withCampaign: false }));
    await assertFails(writeCopies(lea));
  });

  it('should refuse a copy of a street the current campaign does not have', async () => {
    await assertFails(writeCopies(sam, { other: copyDoc() }));
  });

  it('should refuse a copy of a street in the Corbeille, or put in the Corbeille', async () => {
    await assertFails(
      writeCopies(sam, { nationale: copyDoc({ deletedAt: threePm, deletedBy: sam }) }),
    );
    await seed(env, `${streetsPath}/nationale`, streetDoc({ deletedAt: threePm, deletedBy: lea }));
    await assertFails(writeCopies(sam));
  });

  it('should refuse a copy with another name, commune or BAN id', async () => {
    for (const data of [
      copyDoc({ name: 'Rue Gambetta' }),
      copyDoc({ communeName: 'Gleizé' }),
      copyDoc({ communeCode: '69092' }),
      copyDoc({ banId: '69264_0610' }),
    ]) {
      await assertFails(writeCopies(sam, { nationale: data }));
    }
  });

  it('should refuse a copy holding a number the street does not have', async () => {
    const houses = { ...copyDoc().houses, 10: houseEntry(10) };
    await assertFails(writeCopies(sam, { nationale: copyDoc({ houses }) }));
  });

  it('should accept a copy held in part, and refuse a part that is not one', async () => {
    const part = { odd: 'none', even: [2, 30] };
    await assertSucceeds(writeCopies(sam, { nationale: copyDoc({ part }) }));
    await assertFails(
      writeCopies(sam, { nationale: copyDoc({ part: { odd: 'some', even: 'all' } }) }),
    );
  });

  it('should refuse a field the street document does not have', async () => {
    await assertFails(writeCopies(sam, { nationale: copyDoc({ note: 'Mme Martin' }) }));
    await assertFails(writeCopies(sam, { nationale: copyDoc({ assignees: [] }) }));
  });

  it('should refuse a copy into the current or a past campaign', async () => {
    await assertFails(writeCopies(sam, { nationale: copyDoc() }, { year: '2026', withCampaign: false }));
    await seed(env, `${sectorPath}/campaigns/2025`, campaignDoc());
    await assertFails(writeCopies(sam, { nationale: copyDoc() }, { year: '2025', withCampaign: false }));
  });

  it('should accept as many copies in a batch as the adapter sends (copiesPerBatch)', async () => {
    // Each copy reads its own street of the current campaign, and a batch
    // may read at most 20 documents: the admin, the secteur, the campaign
    // and 15 streets fit.
    const copies = {};
    for (let i = 0; i < 15; i += 1) {
      await seed(env, `${streetsPath}/street${i}`, streetDoc());
      copies[`street${i}`] = copyDoc();
    }

    await assertSucceeds(writeCopies(sam, copies));
  });
});

describe('starting the campaign', () => {
  beforeEach(async () => {
    await seed(env, next, nextCampaignDoc());
    await seed(env, `${nextStreets}/nationale`, copyDoc());
  });

  it('should let an admin, member or not, move the secteur to the next year with its preview', async () => {
    await assertSucceeds(startCampaign(sam));
  });

  it('should let an admin move a secteur to any later year holding its copies', async () => {
    await seed(env, sectorPath, sectorDoc({ currentCampaign: 2025 }));
    await seed(env, `joinCodes/${code}`, previewDoc({ campaign: 2025 }));
    await seed(env, next, nextCampaignDoc({ previousYear: 2025 }));

    await assertSucceeds(startCampaign(manu));
  });

  it('should refuse a member who is not an admin', async () => {
    await assertFails(startCampaign(lea));
  });

  it('should refuse a year without its campaign, or copied from another year', async () => {
    await assertFails(startCampaign(sam, 2028));
    await seed(env, `${sectorPath}/campaigns/2028`, nextCampaignDoc({ previousYear: 2025 }));
    await assertFails(startCampaign(sam, 2028));
  });

  it('should refuse going back, or staying on the same year', async () => {
    await seed(env, `${sectorPath}/campaigns/2025`, nextCampaignDoc({ previousYear: 2026 }));
    await assertFails(startCampaign(sam, 2025));
    await assertFails(startCampaign(sam, 2026));
  });

  it('should refuse a year past 2099', async () => {
    await seed(env, sectorPath, sectorDoc({ currentCampaign: 2099 }));
    await seed(env, `${sectorPath}/campaigns/2100`, nextCampaignDoc({ previousYear: 2099 }));
    await assertFails(startCampaign(sam, 2100));
  });

  it('should refuse a move without the preview, or another field with it', async () => {
    await assertFails(startCampaign(sam, 2027, { withPreview: false }));
    const db = phoneOf(env, sam);
    const batch = writeBatch(db);
    batch.update(doc(db, sectorPath), { currentCampaign: 2027, number: 50 });
    batch.update(doc(db, `joinCodes/${code}`), { campaign: 2027 });
    await assertFails(batch.commit());
  });

  it('should refuse the preview changed alone, or anything but its year', async () => {
    await assertFails(updateDoc(doc(phoneOf(env, sam), `joinCodes/${code}`), { campaign: 2027 }));
    const db = phoneOf(env, sam);
    const batch = writeBatch(db);
    batch.update(doc(db, sectorPath), { currentCampaign: 2027 });
    batch.update(doc(db, `joinCodes/${code}`), { campaign: 2027, number: 50 });
    await assertFails(batch.commit());
  });
});

describe('the year left, frozen', () => {
  beforeEach(async () => {
    await seed(env, next, nextCampaignDoc());
    await seed(env, `${nextStreets}/nationale`, copyDoc());
    await seed(env, sectorPath, sectorDoc({ currentCampaign: 2027 }));
    await seed(env, `joinCodes/${code}`, previewDoc({ campaign: 2027 }));
  });

  const mark = (uid, path) =>
    updateFields(doc(phoneOf(env, uid), path), [
      [['houses', '4bis', 'status'], 'DONE'],
      [['houses', '4bis', 'comeBack'], null],
      [['houses', '4bis', 'by'], uid],
      [['houses', '4bis', 'at'], threePm],
    ]);

  it('should still take the marks of the current campaign, as the previous app sends them', async () => {
    await assertSucceeds(mark(lea, `${nextStreets}/nationale`));
  });

  it('should refuse a mark in the year left, from a member or an admin', async () => {
    await assertFails(mark(lea, `${streetsPath}/nationale`));
    await assertFails(mark(sam, `${streetsPath}/nationale`));
  });

  it('should refuse a copy written again once the campaign started: it would wipe its marks', async () => {
    const houses = { ...copyDoc().houses, '4bis': houseEntry(4, { sfx: 'bis', status: 'DONE', by: lea, at: threePm }) };
    await seed(env, `${nextStreets}/nationale`, copyDoc({ houses }));

    await assertFails(writeCopies(sam, { nationale: copyDoc() }, { withCampaign: false }));
  });

  it('should refuse a tournée of the year left, validated or corrected', async () => {
    await assertFails(setDoc(doc(phoneOf(env, lea), `${roundsPath}/Ab12`), roundDoc()));
    await assertFails(
      updateDoc(doc(phoneOf(env, lea), `${roundsPath}/round1`), {
        correctedAt: threePm,
        free: 3,
      }),
    );
    await assertFails(
      updateDoc(doc(phoneOf(env, sam), `${roundsPath}/round1`), {
        correctedAt: threePm,
        free: 3,
      }),
    );
  });
});

describe('deleting a past year', () => {
  it('should let an admin delete its streets, its tournées and itself', async () => {
    const db = phoneOf(env, sam);
    const batch = writeBatch(db);
    batch.delete(doc(db, `${streetsPath}/nationale`));
    batch.delete(doc(db, `${roundsPath}/round1`));
    batch.delete(doc(db, `${sectorPath}/campaigns/2026`));

    await assertSucceeds(batch.commit());
  });

  it('should refuse a member who is not an admin', async () => {
    await assertFails(deleteDoc(doc(phoneOf(env, lea), `${roundsPath}/round1`)));
    await assertFails(deleteDoc(doc(phoneOf(env, lea), `${sectorPath}/campaigns/2026`)));
  });
});

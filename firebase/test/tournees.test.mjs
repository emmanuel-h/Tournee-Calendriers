// Creating, re-coding and deleting a tournée as FirestoreTourneeRepository
// does it (PLAN §8.2 « What the adapters write »), and the directory
// documents that make a tournée findable: join codes, reservations,
// stations.
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import {
  activeMemberDoc,
  campaignDoc,
  campaignPath,
  code,
  lea,
  manu,
  memberPath,
  paul,
  phoneOf,
  previewDoc,
  requestDoc,
  rulesEnvironment,
  seed,
  seedTeam,
  streetDoc,
  streetsPath,
  tourneeDoc,
  tourneePath,
  twoPm,
  zoe,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-tournees');
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
});

/**
 * Zoé creates Tournée 12 of CS Villefranche, in one transaction as the
 * adapter does: it reads the reservation, the code and the station, then
 * writes them with the tournée, her member document and the first
 * campaign. [change] edits the documents before they are written; a
 * document set to `null` is left out of the transaction.
 */
function createTournee(change = (docs) => docs, uid = zoe) {
  // `extra`: more documents written in the same transaction, `[path, data]`.
  const tournee = tourneeDoc({ number: 12, joinCode: 'M4N8RT', createdBy: uid, createdAt: twoPm });
  const docs = change({
    id: 't12',
    tournee,
    key: `${tournee.centreKey}_${tournee.number}`,
    keyDoc: { tourneeId: 't12' },
    preview: { tourneeId: 't12', number: 12, centreName: tournee.centreName, campaign: 2026 },
    member: activeMemberDoc('Zoé', uid, { acceptedAt: twoPm }),
    year: '2026',
    campaign: campaignDoc(),
    centre: null,
    extra: [],
  });
  const db = phoneOf(env, uid);
  return runTransaction(db, async (transaction) => {
    const { centreKey, number } = docs.tournee;
    await transaction.get(doc(db, 'tourneeKeys', `${centreKey}_${number}`));
    await transaction.get(doc(db, 'joinCodes', docs.tournee.joinCode));
    await transaction.get(doc(db, 'rescueCentres', docs.tournee.centreKey));
    if (docs.key !== null) {
      transaction.set(doc(db, 'tourneeKeys', docs.key), docs.keyDoc);
    }
    if (docs.preview !== null) {
      transaction.set(doc(db, 'joinCodes', docs.tournee.joinCode), docs.preview);
    }
    transaction.set(doc(db, 'tournees', docs.id), docs.tournee);
    if (docs.member !== null) {
      transaction.set(doc(db, `tournees/${docs.id}/members/${uid}`), docs.member);
    }
    if (docs.campaign !== null) {
      transaction.set(doc(db, `tournees/${docs.id}/campaigns/${docs.year}`), docs.campaign);
    }
    if (docs.centre !== null) {
      transaction.set(doc(db, 'rescueCentres', docs.tournee.centreKey), docs.centre);
    }
    for (const [path, data] of docs.extra) transaction.set(doc(db, path), data);
  });
}

/** The tournée [docs] with [fields] changed in it, the preview following. */
function withTournee(docs, fields) {
  const tournee = { ...docs.tournee, ...fields };
  return {
    ...docs,
    tournee,
    key: `${tournee.centreKey}_${tournee.number}`,
    preview: {
      ...docs.preview,
      number: tournee.number,
      centreName: tournee.centreName,
      campaign: tournee.currentCampaign,
    },
    year: `${tournee.currentCampaign}`,
  };
}

describe('creating a tournée', () => {
  it('should accept the tournée with its code, reservation, creator and campaign', async () => {
    await assertSucceeds(createTournee());
  });

  it('should accept a new station, written once with the tournée', async () => {
    await assertSucceeds(
      createTournee((docs) => ({
        ...withTournee(docs, { centreKey: 'villefranche-nord', centreName: 'CS Villefranche Nord' }),
        centre: { name: 'CS Villefranche Nord' },
      })),
    );
  });

  it('should refuse a number the station already has', async () => {
    await assertFails(createTournee((docs) => withTournee(docs, { number: 49 })));
  });

  it('should refuse a code another tournée holds', async () => {
    await assertFails(createTournee((docs) => withTournee(docs, { joinCode: code })));
  });

  it('should refuse a tournée without its reservation, code, creator or campaign', async () => {
    await assertFails(createTournee((docs) => ({ ...docs, key: null })));
    await assertFails(createTournee((docs) => ({ ...docs, preview: null })));
    await assertFails(createTournee((docs) => ({ ...docs, member: null })));
    await assertFails(createTournee((docs) => ({ ...docs, campaign: null })));
  });

  it('should refuse a creator membership with another field or no acceptance time', async () => {
    await assertFails(
      createTournee((docs) => ({ ...docs, member: { ...docs.member, joinCode: 'M4N8RT' } })),
    );
    await assertFails(
      createTournee((docs) => ({ ...docs, member: { ...docs.member, acceptedAt: null } })),
    );
  });

  it('should refuse a reservation with another field', async () => {
    await assertFails(
      createTournee((docs) => ({ ...docs, keyDoc: { tourneeId: 't12', number: 12 } })),
    );
  });

  it('should refuse a campaign with another field, a start that is no time, or a previous year', async () => {
    for (const campaign of [
      { ...campaignDoc(), streets: 0 },
      { startedAt: '2026-11-02', previousYear: null },
      { ...campaignDoc(), previousYear: 2025 },
    ]) {
      await assertFails(createTournee((docs) => ({ ...docs, campaign })));
    }
  });

  it('should refuse a second campaign written with the first', async () => {
    await assertFails(
      createTournee((docs) => ({
        ...docs,
        extra: [['tournees/t12/campaigns/2025', campaignDoc()]],
      })),
    );
  });

  it('should refuse a creation time that is not a timestamp', async () => {
    await assertFails(createTournee((docs) => withTournee(docs, { createdAt: 'today' })));
  });

  it('should refuse a creator who is not active', async () => {
    await assertFails(
      createTournee((docs) => ({ ...docs, member: requestDoc('Zoé', { joinCode: 'M4N8RT' }) })),
    );
  });

  it('should refuse a tournée created in someone else’s name', async () => {
    await assertFails(createTournee((docs) => withTournee(docs, { createdBy: lea })));
  });

  it('should refuse a reservation that does not name the tournée’s pair', async () => {
    await assertFails(createTournee((docs) => ({ ...docs, key: 'villefranche_13' })));
  });

  it('should refuse a preview that does not say what the tournée says', async () => {
    await assertFails(
      createTournee((docs) => ({
        ...docs,
        preview: { ...docs.preview, centreName: 'CS Villefranche Nord' },
      })),
    );
    await assertFails(
      createTournee((docs) => ({ ...docs, preview: { ...docs.preview, number: 13 } })),
    );
    await assertFails(
      createTournee((docs) => ({ ...docs, preview: { ...docs.preview, campaign: 2025 } })),
    );
    await assertFails(
      createTournee((docs) => ({ ...docs, preview: { ...docs.preview, members: ['zoe'] } })),
    );
  });

  it('should refuse a preview under a code the tournée does not have', async () => {
    await assertFails(
      createTournee((docs) => ({ ...docs, extra: [['joinCodes/M4N8RU', docs.preview]] })),
    );
  });

  it('should refuse a preview written by someone other than the creator', async () => {
    // Even for the tournée's own code, were its document missing.
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), `joinCodes/${code}`)),
    );

    await assertFails(setDoc(doc(phoneOf(env, lea), `joinCodes/${code}`), previewDoc()));
    await assertSucceeds(setDoc(doc(phoneOf(env, manu), `joinCodes/${code}`), previewDoc()));
  });

  it('should refuse a first campaign that is not the current year', async () => {
    await assertFails(createTournee((docs) => ({ ...docs, year: '2025' })));
  });

  it('should accept numbers 1 and 9999 and refuse 0 and 10000', async () => {
    await assertSucceeds(createTournee((docs) => withTournee(docs, { number: 1 })));
    await env.clearFirestore();
    await assertSucceeds(createTournee((docs) => withTournee(docs, { number: 9999 })));
    await env.clearFirestore();
    await assertFails(createTournee((docs) => withTournee(docs, { number: 0 })));
    await assertFails(createTournee((docs) => withTournee(docs, { number: 10000 })));
  });

  it('should accept the years 2000 and 2099 and refuse 1999 and 2100', async () => {
    await assertSucceeds(createTournee((docs) => withTournee(docs, { currentCampaign: 2000 })));
    await env.clearFirestore();
    await assertSucceeds(createTournee((docs) => withTournee(docs, { currentCampaign: 2099 })));
    await env.clearFirestore();
    await assertFails(createTournee((docs) => withTournee(docs, { currentCampaign: 1999 })));
    await assertFails(createTournee((docs) => withTournee(docs, { currentCampaign: 2100 })));
  });

  it('should accept a station name of 80 characters and refuse 81', async () => {
    await assertSucceeds(
      createTournee((docs) => withTournee(docs, { centreName: '🚒'.repeat(80) })),
    );
    await env.clearFirestore();
    await assertFails(
      createTournee((docs) => withTournee(docs, { centreName: '🚒'.repeat(81) })),
    );
  });

  it('should refuse a station key that is not words of a-z 0-9 joined by dashes', async () => {
    for (const centreKey of ['Villefranche', 'ville franche', 'villefranche-', '-villefranche', 'saône']) {
      await assertFails(createTournee((docs) => withTournee(docs, { centreKey })));
    }
    await assertSucceeds(
      createTournee((docs) => withTournee(docs, { centreKey: 'villefranche-sur-saone' })),
    );
  });

  it('should refuse a code that is not 6 characters of the alphabet', async () => {
    for (const joinCode of ['M4N8R', 'M4N8RTT', 'I4N8RT', 'L4N8RT', 'O4N8RT', '04N8RT', '14N8RT', 'm4n8rt']) {
      await assertFails(createTournee((docs) => withTournee(docs, { joinCode })));
    }
  });

  it('should refuse a field the tournée document does not have', async () => {
    await assertFails(createTournee((docs) => withTournee(docs, { communes: ['69264'] })));
  });

  it('should refuse an active member document added to an existing tournée', async () => {
    await assertFails(
      setDoc(doc(phoneOf(env, zoe), memberPath(zoe)), activeMemberDoc('Zoé', zoe)),
    );
  });

  it('should refuse a reservation or a campaign written without their tournée', async () => {
    const db = phoneOf(env, manu);
    await assertFails(setDoc(doc(db, 'tourneeKeys/villefranche_50'), { tourneeId: 't49' }));
    await assertFails(setDoc(doc(db, `${tourneePath}/campaigns/2027`), campaignDoc()));
  });
});

describe('the directory', () => {
  it('should let a signed-in user get a code and refuse the signed out', async () => {
    await assertSucceeds(getDoc(doc(phoneOf(env, zoe), `joinCodes/${code}`)));
    await assertFails(getDoc(doc(phoneOf(env, null), `joinCodes/${code}`)));
  });

  it('should refuse listing the codes, even searching one tournée', async () => {
    const db = phoneOf(env, zoe);
    await assertFails(getDocs(collection(db, 'joinCodes')));
    await assertFails(getDocs(query(collection(db, 'joinCodes'), where('number', '==', 49))));
  });

  it('should refuse replacing another tournée’s preview', async () => {
    await assertFails(
      setDoc(doc(phoneOf(env, zoe), `joinCodes/${code}`), previewDoc({ tourneeId: 't12' })),
    );
    await assertFails(
      updateDoc(doc(phoneOf(env, manu), `joinCodes/${code}`), { centreName: 'CS Villefranche Nord' }),
    );
  });

  it('should let a signed-in user get a reservation, not list or change them', async () => {
    const db = phoneOf(env, zoe);
    await assertSucceeds(getDoc(doc(db, 'tourneeKeys/villefranche_49')));
    await assertFails(getDocs(collection(db, 'tourneeKeys')));
    await assertFails(setDoc(doc(db, 'tourneeKeys/villefranche_49'), { tourneeId: 't12' }));
    await assertFails(getDoc(doc(phoneOf(env, null), 'tourneeKeys/villefranche_49')));
  });

  it('should let a signed-in user list the stations', async () => {
    await assertSucceeds(getDocs(collection(phoneOf(env, zoe), 'rescueCentres')));
    await assertFails(getDocs(collection(phoneOf(env, null), 'rescueCentres')));
  });

  it('should accept a new station and refuse changing or deleting one', async () => {
    const db = phoneOf(env, zoe);
    await assertSucceeds(setDoc(doc(db, 'rescueCentres/villefranche-nord'), { name: 'CS Villefranche Nord' }));
    await assertFails(setDoc(doc(db, 'rescueCentres/villefranche'), { name: 'CS Ville' }));
    await assertFails(deleteDoc(doc(db, 'rescueCentres/villefranche')));
  });

  it('should refuse a station with a bad key, a long name or another field', async () => {
    const db = phoneOf(env, zoe);
    await assertFails(setDoc(doc(db, 'rescueCentres/Villefranche-Nord'), { name: 'CS Villefranche Nord' }));
    await assertFails(setDoc(doc(db, 'rescueCentres/villefranche-nord'), { name: '🚒'.repeat(81) }));
    await assertSucceeds(setDoc(doc(db, 'rescueCentres/villefranche-nord'), { name: '🚒'.repeat(80) }));
    await assertFails(
      setDoc(doc(db, 'rescueCentres/villefranche-sud'), { name: 'CS Villefranche Sud', chief: 'x' }),
    );
    await assertFails(setDoc(doc(phoneOf(env, null), 'rescueCentres/villefranche-est'), { name: 'CS Villefranche Est' }));
  });
});

describe('a new code', () => {
  /** [uid] replaces K7P2QX by [next], as the adapter's transaction does. */
  function newCode(uid, { next = 'R2D2XY', update = { joinCode: next }, dropOld = true, preview = previewDoc() } = {}) {
    const db = phoneOf(env, uid);
    return runTransaction(db, async (transaction) => {
      await transaction.get(doc(db, 'joinCodes', next));
      transaction.update(doc(db, tourneePath), update);
      if (dropOld) transaction.delete(doc(db, 'joinCodes', code));
      if (preview !== null) transaction.set(doc(db, 'joinCodes', next), preview);
    });
  }

  it('should let the creator replace the code', async () => {
    await assertSucceeds(newCode(manu));
  });

  it('should refuse another member', async () => {
    await assertFails(newCode(lea));
  });

  it('should refuse a new code that leaves the old one findable', async () => {
    await assertFails(newCode(manu, { dropOld: false }));
  });

  it('should refuse a new code without its preview', async () => {
    await assertFails(newCode(manu, { preview: null }));
  });

  it('should refuse a code outside the alphabet', async () => {
    await assertFails(newCode(manu, { next: 'R2D2XI' }));
  });

  it('should refuse any other change of the tournée', async () => {
    await assertFails(newCode(manu, { update: { joinCode: 'R2D2XY', currentCampaign: 2027 } }));
    await assertFails(
      newCode(manu, {
        update: { joinCode: 'R2D2XY', centreName: 'CS Villefranche Nord' },
        preview: previewDoc({ centreName: 'CS Villefranche Nord' }),
      }),
    );
    await assertFails(updateDoc(doc(phoneOf(env, manu), tourneePath), { number: 50 }));
  });

  it('should refuse deleting the code while the tournée keeps it', async () => {
    await assertFails(deleteDoc(doc(phoneOf(env, manu), `joinCodes/${code}`)));
  });
});

describe('deleting a tournée', () => {
  /** The adapter's order: the contents first, then the last batch. */
  async function deleteContents(uid) {
    const db = phoneOf(env, uid);
    const batch = writeBatch(db);
    batch.delete(doc(db, `${streetsPath}/nationale`));
    batch.delete(doc(db, campaignPath));
    batch.delete(doc(db, memberPath(lea)));
    batch.delete(doc(db, memberPath(paul)));
    await batch.commit();
  }

  function lastBatch(uid, { keepMember = false, keepCode = false, keepKey = false } = {}) {
    const db = phoneOf(env, uid);
    const batch = writeBatch(db);
    if (!keepCode) batch.delete(doc(db, `joinCodes/${code}`));
    if (!keepKey) batch.delete(doc(db, 'tourneeKeys/villefranche_49'));
    batch.delete(doc(db, tourneePath));
    if (!keepMember) batch.delete(doc(db, memberPath(manu)));
    return batch.commit();
  }

  it('should let the creator delete everything, their member document last', async () => {
    await assertSucceeds(deleteContents(manu));
    await assertSucceeds(lastBatch(manu));
  });

  it('should let the creator delete a batch of 500 streets', async () => {
    // Each delete reads the tournée and the creator's member document: in a
    // batch the rules read each document once, whatever the count.
    const ids = Array.from({ length: 500 }, (_, i) => `street${i}`);
    await Promise.all(ids.map((id) => seed(env, `${streetsPath}/${id}`, streetDoc({ houses: {} }))));
    const db = phoneOf(env, manu);
    const batch = writeBatch(db);
    for (const id of ids) batch.delete(doc(db, `${streetsPath}/${id}`));

    await assertSucceeds(batch.commit());
  });

  it('should refuse another member', async () => {
    await assertFails(deleteContents(lea));
    await assertFails(lastBatch(lea));
  });

  it('should refuse a tournée deleted without its code, reservation or creator', async () => {
    await assertFails(lastBatch(manu, { keepCode: true }));
    await assertFails(lastBatch(manu, { keepKey: true }));
    await assertFails(lastBatch(manu, { keepMember: true }));
  });

  it('should refuse another member deleting a campaign', async () => {
    await assertFails(deleteDoc(doc(phoneOf(env, lea), campaignPath)));
  });

  it('should refuse freeing the reservation while the tournée stays', async () => {
    await assertFails(deleteDoc(doc(phoneOf(env, manu), 'tourneeKeys/villefranche_49')));
  });
});

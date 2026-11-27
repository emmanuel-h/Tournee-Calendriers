// What the app on Play before PLAN §5.23 (0.25.1) writes as the only real
// admin, the user: their `admins/{uid}`, set by hand in the console before
// these rules are deployed, holds both global permissions and every
// permission in their only CS (superAdminDoc), and nothing else. Each admin
// write of that app must still pass for them (CLAUDE.md « Rules accept the
// previous app »), and still be refused to an admin of another CS.
//
// The other test files write as that app too, Manu holding the same
// document; here are the admin flows end to end, in the adapters' order.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  collection,
  deleteField,
  doc,
  getDocs,
  runTransaction,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import {
  activeMemberDoc,
  adminDoc,
  allPermissions,
  at,
  campaignDoc,
  campaignPath,
  code,
  gleizeEntry,
  houseEntry,
  lea,
  manu,
  memberPath,
  namePath,
  newStreetDoc,
  paul,
  phoneOf,
  previewDoc,
  roundsPath,
  rulesEnvironment,
  sectorDoc,
  sectorPath,
  seed,
  seedTeam,
  streetsPath,
  superAdminDoc,
  twoPm,
  updateFields,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-previous-app');
});

after(() => env.cleanup());

/** An admin of the CS Gleizé with every permission there, and nothing here. */
const gael = 'gael';

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
  await seed(env, `admins/${gael}`, adminDoc('Gaël', { gleize: allPermissions }));
});

/**
 * [uid] creates Secteur [number] of [centreKey] / [centreName] as the
 * previous app's transaction does (FirestoreSectorRepository.add): it
 * reads the reservation, the code and the station, then writes them with
 * the secteur, the creator, the name and the first campaign, and the
 * station when it was not there.
 */
function createSector(uid, { id = 't12', number = 12, centreKey = 'villefranche', centreName = 'CS Villefranche', joinCode = 'M4N8RT' } = {}) {
  const db = phoneOf(env, uid);
  return runTransaction(db, async (transaction) => {
    await transaction.get(doc(db, `sectorKeys/${centreKey}_${number}`));
    await transaction.get(doc(db, `joinCodes/${joinCode}`));
    const centre = await transaction.get(doc(db, `rescueCentres/${centreKey}`));
    transaction
      .set(doc(db, `sectorKeys/${centreKey}_${number}`), { sectorId: id })
      .set(doc(db, `joinCodes/${joinCode}`), { sectorId: id, number, centreName, campaign: 2026 })
      .set(
        doc(db, `sectors/${id}`),
        sectorDoc({ number, centreKey, centreName, joinCode, createdBy: uid }),
      )
      .set(doc(db, `sectors/${id}/members/${uid}`), activeMemberDoc('Manu', uid, { acceptedAt: twoPm }))
      .set(doc(db, `sectors/${id}/names/manu`), { member: uid })
      .set(doc(db, `sectors/${id}/campaigns/2026`), campaignDoc());
    if (!centre.exists()) {
      transaction.set(doc(db, `rescueCentres/${centreKey}`), { name: centreName });
    }
  });
}

describe('the user\'s admin document', () => {
  it('should be exactly what the console set', async () => {
    let stored;
    await env.withSecurityRulesDisabled(async (context) => {
      stored = (await getDocs(collection(context.firestore(), 'admins'))).docs
        .find((admin) => admin.id === manu)
        .data();
    });
    assert.deepEqual(stored, superAdminDoc());
  });
});

describe('creating a secteur, as the previous app does', () => {
  it('should accept one in the user\'s CS, the station already there', async () => {
    await assertSucceeds(createSector(manu));
  });

  it('should accept one in a new CS, with its station', async () => {
    await assertSucceeds(
      createSector(manu, { id: 'a7', number: 7, centreKey: 'anse', centreName: 'CS Anse' }),
    );
  });

  it('should refuse an admin of another CS', async () => {
    await assertFails(createSector(gael));
  });
});

describe('the team, as the previous app does', () => {
  beforeEach(async () => {
    // Secteur 12 of Léa, which the user is not in.
    await seed(env, 'sectors/t12', sectorDoc({ number: 12, joinCode: 'M4N8RT', createdBy: lea }));
    await seed(env, 'sectors/t12/members/lea', activeMemberDoc('Léa', lea));
    await seed(env, 'sectors/t12/names/lea', { member: lea });
    await seed(env, 'sectors/t12/campaigns/2026', campaignDoc());
  });

  /** [uid] joins the 12 without a code (« Rejoindre » of the banner). */
  const join = (uid) => {
    const db = phoneOf(env, uid);
    return runTransaction(db, async (transaction) => {
      await transaction.get(doc(db, 'sectors/t12/names/manu'));
      transaction
        .set(doc(db, `sectors/t12/members/${uid}`), activeMemberDoc('Manu', uid))
        .set(doc(db, 'sectors/t12/names/manu'), { member: uid });
    });
  };

  it('should let the user join a secteur without a code', async () => {
    await assertFails(join(gael));
    await assertSucceeds(join(manu));
  });

  it('should let the user accept a request and remove a member', async () => {
    await assertSucceeds(
      updateDoc(doc(phoneOf(env, manu), memberPath(paul)), {
        status: 'active',
        acceptedBy: manu,
        acceptedAt: twoPm,
      }),
    );
    const removal = (uid) => {
      const db = phoneOf(env, uid);
      return writeBatch(db)
        .delete(doc(db, memberPath(lea)))
        .delete(doc(db, namePath('lea')))
        .commit();
    };
    await assertFails(removal(gael));
    await assertSucceeds(removal(manu));
  });

  it('should let the user draw a new code', async () => {
    const db = phoneOf(env, manu);
    await assertSucceeds(
      runTransaction(db, async (transaction) => {
        await transaction.get(doc(db, 'joinCodes/R2D2XY'));
        transaction
          .update(doc(db, sectorPath), { joinCode: 'R2D2XY' })
          .delete(doc(db, `joinCodes/${code}`))
          .set(doc(db, 'joinCodes/R2D2XY'), previewDoc());
      }),
    );
  });

  it('should let the user work on the streets of a secteur they visit', async () => {
    const db = phoneOf(env, manu);
    await assertSucceeds(
      updateDoc(doc(db, 'sectors/t12'), { communes: arrayUnion(gleizeEntry) }),
    );
    await assertSucceeds(
      setDoc(doc(db, 'sectors/t12/campaigns/2026/streets/paix'), newStreetDoc()),
    );
  });
});

describe('deleting a secteur, as the previous app does', () => {
  it('should let the user delete it all: index entries, contents, then the last batch, then what is left', async () => {
    const db = phoneOf(env, manu);
    await seed(env, 'streetParts/69264_0420', {
      sector: 't49',
      parts: { t49: { number: 49, centreName: 'CS Villefranche', odd: 'all', even: 'all' } },
    });
    // The secteur's entry in the shared index of its BAN streets.
    await assertSucceeds(
      setDoc(
        doc(db, 'streetParts/69264_0420'),
        { sector: 't49', parts: { t49: deleteField() } },
        { merge: true },
      ),
    );
    await assertSucceeds(
      writeBatch(db)
        .delete(doc(db, `${streetsPath}/nationale`))
        .delete(doc(db, `${roundsPath}/round1`))
        .delete(doc(db, campaignPath))
        .commit(),
    );
    const last = writeBatch(db)
      .delete(doc(db, `joinCodes/${code}`))
      .delete(doc(db, 'sectorKeys/villefranche_49'))
      .delete(doc(db, sectorPath));
    for (const member of [manu, lea, paul]) last.delete(doc(db, memberPath(member)));
    for (const key of ['manu', 'lea', 'paul']) last.delete(doc(db, namePath(key)));
    await assertSucceeds(last.commit());
    // The members and names listed again once it is gone, a request sent
    // at that moment deleted.
    await seed(env, memberPath('zoe'), { displayName: 'Zoé', status: 'pending' });
    await assertSucceeds(getDocs(collection(db, `${sectorPath}/members`)));
    await assertSucceeds(getDocs(collection(db, `${sectorPath}/names`)));
    await assertSucceeds(writeBatch(db).delete(doc(db, memberPath('zoe'))).commit());
  });

  it('should refuse an admin of another CS', async () => {
    const db = phoneOf(env, gael);
    await assertFails(writeBatch(db).delete(doc(db, `${streetsPath}/nationale`)).commit());
    await assertFails(
      writeBatch(db)
        .delete(doc(db, `joinCodes/${code}`))
        .delete(doc(db, 'sectorKeys/villefranche_49'))
        .delete(doc(db, sectorPath))
        .commit(),
    );
  });
});

describe('a new campaign, as the previous app does', () => {
  it('should let the user write the next year, copy the streets, start it and delete a past year', async () => {
    const db = phoneOf(env, manu);
    await seed(env, `${sectorPath}/campaigns/2025`, campaignDoc());
    await assertSucceeds(
      writeBatch(db)
        .set(doc(db, `${sectorPath}/campaigns/2027`), { startedAt: at('2027-09-01T08:00:00Z'), previousYear: 2026 })
        .set(doc(db, `${sectorPath}/campaigns/2027/streets/nationale`), {
          ...newStreetDoc({ name: 'Rue Nationale', banId: '69264_0420' }),
          houses: { 4: houseEntry(4) },
        })
        .commit(),
    );
    await assertSucceeds(
      writeBatch(db)
        .update(doc(db, sectorPath), { currentCampaign: 2027 })
        .update(doc(db, `joinCodes/${code}`), { campaign: 2027 })
        .commit(),
    );
    await assertSucceeds(
      writeBatch(db).delete(doc(db, `${sectorPath}/campaigns/2025`)).commit(),
    );
  });

  it('should refuse an admin of another CS', async () => {
    await assertFails(
      setDoc(doc(phoneOf(env, gael), `${sectorPath}/campaigns/2027`), {
        startedAt: at('2027-09-01T08:00:00Z'),
        previousYear: 2026,
      }),
    );
  });
});

describe('the undo of « Restaurer », naming an admin as the remover', () => {
  /** Léa undoes « Restaurer » of the 4bis [remover] had removed (PLAN §6.2). */
  const undo = (remover) =>
    updateFields(doc(phoneOf(env, lea), `${streetsPath}/nationale`), [
      [['houses', '4bis', 'deletedAt'], twoPm],
      [['houses', '4bis', 'deletedBy'], remover],
    ]);

  it('should accept an admin with « Rues » in the CS, outside the team', async () => {
    await assertSucceeds(undo('sam'));
  });

  it('should refuse an admin of another CS', async () => {
    await assertFails(undo(gael));
  });
});

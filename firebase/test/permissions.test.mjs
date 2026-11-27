// The permission matrix of PLAN §5.23 (« Security »): each operation an
// admin's permission covers, tried by an admin holding each permission
// alone in the secteur's CS, by an admin holding every permission in
// another CS, by the super admin holding the global permissions alone, by
// an active member and by a signed-in stranger. Allowed or refused as the
// matrix says; one test per cell, each on a fresh team.
//
// The secteur is the 49 of the CS Villefranche (seedTeam). Holding a global
// permission gives no power over a secteur (least privilege): the super
// admin's own come from their CS grants, as anyone's.
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import {
  activeMemberDoc,
  adminDoc,
  allPermissions,
  at,
  campaignDoc,
  code,
  gleizeEntry,
  lea,
  manu,
  memberPath,
  namePath,
  newStreetDoc,
  paul,
  phoneOf,
  previewDoc,
  roundDons,
  roundsPath,
  rulesEnvironment,
  sectorDoc,
  sectorPath,
  seed,
  seedTeam,
  streetsPath,
  twoPm,
  zoe,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-permissions');
});

after(() => env.cleanup());

// The callers, one column each.
const campaignAdmin = 'adminCampaign';
const sectorsAdmin = 'adminSectors';
const teamsAdmin = 'adminTeams';
const streetsAdmin = 'adminStreets';
const otherCsAdmin = 'adminGleize';
const superOnly = 'superOnly';

const columns = [
  ['an admin with « Campagne » in the CS', campaignAdmin],
  ['an admin with « Secteurs » in the CS', sectorsAdmin],
  ['an admin with « Équipes » in the CS', teamsAdmin],
  ['an admin with « Rues » in the CS', streetsAdmin],
  ['an admin with every permission in another CS', otherCsAdmin],
  ['the super admin with the global permissions alone', superOnly],
  ['an active member', lea],
  ['a signed-in stranger', zoe],
];

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
  await seed(env, `admins/${campaignAdmin}`, adminDoc('Camille', { villefranche: ['campaign'] }));
  await seed(env, `admins/${sectorsAdmin}`, adminDoc('Sébastien', { villefranche: ['sectors'] }));
  await seed(env, `admins/${teamsAdmin}`, adminDoc('Théo', { villefranche: ['teams'] }));
  await seed(env, `admins/${streetsAdmin}`, adminDoc('Rose', { villefranche: ['streets'] }));
  await seed(env, `admins/${otherCsAdmin}`, adminDoc('Gaël', { gleize: allPermissions }));
  await seed(env, `admins/${superOnly}`, { global: ['admins', 'centres'] });
  await seed(env, 'rescueCentres/gleize', { name: 'CS Gleizé' });
  // Léa's phone names the 49 as the secteur it has open (#147).
  await seed(env, `openSectors/${lea}`, { sectorId: 't49' });
  // A year the secteur no longer works on, to delete (PLAN §5.10).
  await seed(env, `${sectorPath}/campaigns/2025`, campaignDoc());
  await seed(env, `${sectorPath}/campaigns/2025/streets/ancienne`, newStreetDoc());
});

/**
 * [uid] creates Secteur 12 of the CS Villefranche as the adapter's
 * transaction does (FirestoreSectorRepository.add).
 */
function createSector(uid) {
  const db = phoneOf(env, uid);
  return runTransaction(db, async (transaction) => {
    await transaction.get(doc(db, 'sectorKeys/villefranche_12'));
    await transaction.get(doc(db, 'joinCodes/M4N8RT'));
    await transaction.get(doc(db, 'rescueCentres/villefranche'));
    transaction
      .set(doc(db, 'sectorKeys/villefranche_12'), { sectorId: 't12' })
      .set(doc(db, 'joinCodes/M4N8RT'), {
        sectorId: 't12',
        number: 12,
        centreName: 'CS Villefranche',
        campaign: 2026,
      })
      .set(doc(db, 'sectors/t12'), sectorDoc({ number: 12, joinCode: 'M4N8RT', createdBy: uid }))
      .set(doc(db, `sectors/t12/members/${uid}`), activeMemberDoc('Xavier', uid, { acceptedAt: twoPm }))
      .set(doc(db, 'sectors/t12/names/xavier'), { member: uid })
      .set(doc(db, 'sectors/t12/campaigns/2026'), campaignDoc());
  });
}

/** [uid] replaces the code K7P2QX by R2D2XY, as the adapter's transaction does. */
function newCode(uid) {
  const db = phoneOf(env, uid);
  return runTransaction(db, async (transaction) => {
    await transaction.get(doc(db, 'joinCodes/R2D2XY'));
    transaction
      .update(doc(db, sectorPath), { joinCode: 'R2D2XY' })
      .delete(doc(db, `joinCodes/${code}`))
      .set(doc(db, 'joinCodes/R2D2XY'), previewDoc());
  });
}

/**
 * [uid] sends the last batch of « Supprimer le secteur »: the code, the
 * reservation, the secteur, every member and the names they hold.
 */
function deleteSector(uid) {
  const db = phoneOf(env, uid);
  const batch = writeBatch(db)
    .delete(doc(db, `joinCodes/${code}`))
    .delete(doc(db, 'sectorKeys/villefranche_49'))
    .delete(doc(db, sectorPath));
  for (const member of [manu, lea, paul]) batch.delete(doc(db, memberPath(member)));
  for (const key of ['manu', 'lea', 'paul']) batch.delete(doc(db, namePath(key)));
  return batch.commit();
}

/** [uid] joins the 49 without a code, as an admin (« Rejoindre »). */
function joinWithoutCode(uid) {
  const db = phoneOf(env, uid);
  return writeBatch(db)
    .set(doc(db, memberPath(uid)), activeMemberDoc('Xavier', uid))
    .set(doc(db, namePath('xavier')), { member: uid })
    .commit();
}

/** [uid] removes Manu, an active member, with the name he holds. */
function removeManu(uid) {
  const db = phoneOf(env, uid);
  return writeBatch(db)
    .delete(doc(db, memberPath(manu)))
    .delete(doc(db, namePath('manu')))
    .commit();
}

/** [uid] corrects the validated tournée round1 (#168). */
function correctRound(uid) {
  return updateDoc(doc(phoneOf(env, uid), `${roundsPath}/round1`), {
    free: 2,
    cash: { count: 15, cents: 21000 },
    cheque: { count: 3, cents: 6000 },
    card: { count: 2, cents: 1500 },
    dons: [...roundDons(), 'card:500'],
    correctedAt: at('2026-10-25T09:00:00Z'),
    housesToMark: increment(1),
  });
}

// Each operation, then who may run it among the columns, in order:
// Campagne, Secteurs, Équipes, Rues, another CS, super admin, member,
// stranger. `true` allowed, `false` refused.
const Y = true;
const N = false;
const matrix = [
  ['read the secteur',
    (uid) => getDoc(doc(phoneOf(env, uid), sectorPath)),
    [Y, Y, Y, Y, N, N, Y, N]],
  ['list the secteurs of the CS',
    (uid) => getDocs(query(collection(phoneOf(env, uid), 'sectors'), where('centreKey', 'in', ['villefranche']))),
    [Y, Y, Y, Y, N, N, N, N]],
  ['read the streets',
    (uid) => getDocs(collection(phoneOf(env, uid), streetsPath)),
    [Y, Y, Y, Y, N, N, Y, N]],
  ['ask whether a number is taken in the CS',
    (uid) => getDoc(doc(phoneOf(env, uid), 'sectorKeys/villefranche_12')),
    [N, Y, N, N, N, N, N, N]],
  ['create a secteur in the CS',
    createSector,
    [N, Y, N, N, N, N, N, N]],
  ['draw a new code',
    newCode,
    [N, Y, N, N, N, N, N, N]],
  ['delete the secteur',
    deleteSector,
    [N, Y, N, N, N, N, N, N]],
  ['accept a request',
    (uid) => updateDoc(doc(phoneOf(env, uid), memberPath(paul)), {
      status: 'active',
      acceptedBy: uid,
      acceptedAt: twoPm,
    }),
    [N, N, Y, N, N, N, Y, N]],
  ['remove an active member',
    removeManu,
    [N, N, Y, N, N, N, N, N]],
  ['join without a code',
    joinWithoutCode,
    [N, N, Y, N, N, N, N, N]],
  ['add a street',
    (uid) => setDoc(doc(phoneOf(env, uid), `${streetsPath}/paix`), newStreetDoc()),
    [N, N, N, Y, N, N, Y, N]],
  ['add a commune',
    (uid) => updateDoc(doc(phoneOf(env, uid), sectorPath), { communes: arrayUnion(gleizeEntry) }),
    [N, N, N, Y, N, N, Y, N]],
  ['delete a street outright (unreadable)',
    (uid) => deleteDoc(doc(phoneOf(env, uid), `${streetsPath}/nationale`)),
    [N, Y, N, Y, N, N, N, N]],
  ['start the next campaign',
    (uid) => setDoc(doc(phoneOf(env, uid), `${sectorPath}/campaigns/2027`), {
      startedAt: at('2027-09-01T08:00:00Z'),
      previousYear: 2026,
    }),
    [Y, N, N, N, N, N, N, N]],
  ['delete a year the secteur no longer keeps',
    (uid) => deleteDoc(doc(phoneOf(env, uid), `${sectorPath}/campaigns/2025/streets/ancienne`)),
    [Y, Y, N, N, N, N, N, N]],
  ['delete the current year',
    (uid) => deleteDoc(doc(phoneOf(env, uid), `${sectorPath}/campaigns/2026`)),
    [N, Y, N, N, N, N, N, N]],
  ['correct a validated tournée',
    correctRound,
    [Y, N, N, N, N, N, Y, N]],
  ['read the shared index of streets',
    (uid) => getDoc(doc(phoneOf(env, uid), 'streetParts/69264_0420')),
    [Y, Y, Y, Y, Y, N, Y, N]],
  ['create a new CS',
    (uid) => setDoc(doc(phoneOf(env, uid), 'rescueCentres/anse'), { name: 'CS Anse' }),
    [N, N, N, N, N, Y, N, N]],
  ['list the admins',
    (uid) => getDocs(collection(phoneOf(env, uid), 'admins')),
    [N, N, N, N, N, Y, N, N]],
  ['name an admin',
    (uid) => setDoc(doc(phoneOf(env, uid), 'admins/newcomer'), adminDoc('Nina', { villefranche: ['teams'] }, { addedBy: uid })),
    [N, N, N, N, N, Y, N, N]],
];

for (const [operation, run, allowed] of matrix) {
  describe(`to ${operation}`, () => {
    for (const [index, [who, uid]] of columns.entries()) {
      const verdict = allowed[index] ? 'allow' : 'refuse';
      it(`should ${verdict} ${who}`, async () => {
        await (allowed[index] ? assertSucceeds : assertFails)(run(uid));
      });
    }
  });
}

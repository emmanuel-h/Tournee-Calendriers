// The administrators of the app (PLAN §5.12, §5.23, the « Admins » block of
// §8.2): an `admins/{uid}` document makes a phone an admin of the CS it
// grants permissions in, member of their secteurs or not; the super admin
// (the global `admins`, set in the console) writes the others. Sam is an
// admin of the CS Villefranche in no secteur; Manu, who created Secteur 49,
// is the super admin with every permission there too; Léa is a member who
// is not an admin. The permission matrix is permissions.test.mjs.
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
  adminDoc,
  allPermissions,
  at,
  campaignPath,
  code,
  houseEntry,
  lea,
  manu,
  memberPath,
  namePath,
  newStreetDoc,
  paul,
  phoneOf,
  writeWithName,
  previewDoc,
  roundsPath,
  rulesEnvironment,
  sam,
  seed,
  seedTeam,
  sectorDoc,
  superAdminDoc,
  streetDoc,
  streetsPath,
  threePm,
  sectorPath,
  updateFields,
  zoe,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-admins');
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
});

/** The member document of [member], as [uid]'s phone sees it. */
const memberOf = (uid, member) => doc(phoneOf(env, uid), memberPath(member));

describe('the admin documents', () => {
  it('should let a signed-in user get one, to show « · admin »', async () => {
    await assertSucceeds(getDoc(doc(phoneOf(env, lea), `admins/${manu}`)));
    await assertSucceeds(getDoc(doc(phoneOf(env, zoe), `admins/${zoe}`)));
  });

  it('should refuse getting one when signed out', async () => {
    await assertFails(getDoc(doc(phoneOf(env, null), `admins/${manu}`)));
  });

  it('should refuse listing them', async () => {
    await assertFails(getDocs(collection(phoneOf(env, sam), 'admins')));
  });

  it('should refuse any write, even by an admin', async () => {
    await assertFails(setDoc(doc(phoneOf(env, zoe), `admins/${zoe}`), {}));
    await assertFails(setDoc(doc(phoneOf(env, sam), `admins/${lea}`), {}));
    await assertFails(deleteDoc(doc(phoneOf(env, sam), `admins/${manu}`)));
    await assertFails(updateDoc(doc(phoneOf(env, sam), `admins/${sam}`), { x: 1 }));
  });
});

describe('the admin documents, written by the super admin (PLAN §5.23)', () => {
  /** [uid]'s phone's reference to `admins/{admin}`. */
  const adminRef = (uid, admin) => doc(phoneOf(env, uid), `admins/${admin}`);

  /** The document Manu writes to name Nina an admin of the CS Villefranche. */
  const nina = (overrides = {}) =>
    adminDoc('Nina', { villefranche: ['teams', 'streets'] }, { addedBy: manu, ...overrides });

  /** [count] CS of well-formed keys, each with « Équipes ». */
  const centres = (count) =>
    Object.fromEntries(Array.from({ length: count }, (_, i) => [`cs-${i}`, ['teams']]));

  it('should let the super admin list them, and nobody else', async () => {
    await assertSucceeds(getDocs(collection(phoneOf(env, manu), 'admins')));
    await assertFails(getDocs(collection(phoneOf(env, sam), 'admins')));
    await assertFails(getDocs(collection(phoneOf(env, lea), 'admins')));
  });

  it('should let the super admin name an admin with exactly the fields', async () => {
    await assertSucceeds(setDoc(adminRef(manu, 'nina'), nina()));
  });

  it('should refuse an admin named by anyone else', async () => {
    await assertFails(setDoc(adminRef(sam, 'nina'), nina({ addedBy: sam })));
    await assertFails(setDoc(adminRef(lea, 'nina'), nina({ addedBy: lea })));
    await assertFails(setDoc(adminRef(zoe, zoe), nina({ addedBy: zoe })));
  });

  it('should refuse a new admin with a global permission, another field, or one missing', async () => {
    await assertFails(setDoc(adminRef(manu, 'nina'), nina({ global: ['admins'] })));
    await assertFails(setDoc(adminRef(manu, 'nina'), nina({ global: [] })));
    await assertFails(setDoc(adminRef(manu, 'nina'), nina({ super: true })));
    const { updatedAt: _, ...noUpdate } = nina();
    await assertFails(setDoc(adminRef(manu, 'nina'), noUpdate));
  });

  it('should refuse a new admin added in someone else\'s name, or with times that are not', async () => {
    await assertFails(setDoc(adminRef(manu, 'nina'), nina({ addedBy: sam })));
    await assertFails(setDoc(adminRef(manu, 'nina'), nina({ addedAt: '2026-11-02' })));
    await assertFails(setDoc(adminRef(manu, 'nina'), nina({ updatedAt: null })));
  });

  it('should take a name of 1 to 30 characters, cleaned', async () => {
    await assertSucceeds(setDoc(adminRef(manu, 'a'), nina({ name: '🚒'.repeat(30) })));
    await assertFails(setDoc(adminRef(manu, 'b'), nina({ name: '🚒'.repeat(31) })));
    await assertFails(setDoc(adminRef(manu, 'c'), nina({ name: '' })));
    await assertFails(setDoc(adminRef(manu, 'd'), nina({ name: ' Nina' })));
  });

  it('should take up to 50 CS, under well-formed keys', async () => {
    await assertSucceeds(setDoc(adminRef(manu, 'a'), nina({ centres: centres(50) })));
    await assertSucceeds(setDoc(adminRef(manu, 'b'), nina({ centres: {} })));
    await assertFails(setDoc(adminRef(manu, 'c'), nina({ centres: centres(51) })));
    for (const key of ['Gleizé', 'gleize-', 'ville franche', 'anse,gleize', 'anse_12']) {
      await assertFails(
        setDoc(adminRef(manu, 'd'), nina({ centres: { villefranche: ['teams'], [key]: ['teams'] } })),
        key,
      );
    }
    await assertFails(setDoc(adminRef(manu, 'e'), nina({ centres: ['villefranche'] })));
  });

  it('should let the super admin change another admin\'s name and CS', async () => {
    await assertSucceeds(
      updateDoc(adminRef(manu, sam), {
        name: 'Samuel',
        centres: { gleize: ['campaign'] },
        updatedAt: threePm,
      }),
    );
  });

  it('should let the super admin change their own CS, never their global permissions', async () => {
    await assertSucceeds(
      updateDoc(adminRef(manu, manu), {
        centres: { villefranche: ['teams'], gleize: ['sectors'] },
        updatedAt: threePm,
      }),
    );
    await assertFails(
      updateDoc(adminRef(manu, manu), { global: ['admins'], updatedAt: threePm }),
    );
  });

  it('should refuse an update giving a global permission, or touching another field', async () => {
    await assertFails(updateDoc(adminRef(manu, sam), { global: ['centres'], updatedAt: threePm }));
    await assertFails(updateDoc(adminRef(manu, sam), { addedBy: lea, updatedAt: threePm }));
    await assertFails(updateDoc(adminRef(manu, sam), { addedAt: threePm, updatedAt: threePm }));
    await assertFails(updateDoc(adminRef(manu, sam), { centres: centres(51), updatedAt: threePm }));
    await assertFails(updateDoc(adminRef(manu, sam), { name: '', updatedAt: threePm }));
    await assertFails(updateDoc(adminRef(manu, sam), { centres: {}, updatedAt: 'now' }));
  });

  it('should refuse an admin changing their own document without « admins »', async () => {
    await assertFails(
      updateDoc(adminRef(sam, sam), { centres: { gleize: allPermissions }, updatedAt: threePm }),
    );
  });

  it('should let the super admin remove an admin, never a holder of a global permission', async () => {
    await seed(env, 'admins/other', { global: ['centres'], centres: {} });

    await assertFails(deleteDoc(adminRef(manu, 'other')));
    await assertFails(
      updateDoc(adminRef(manu, 'other'), { centres: { villefranche: ['teams'] }, updatedAt: threePm }),
    );
    await assertFails(deleteDoc(adminRef(manu, manu)));
    await assertSucceeds(deleteDoc(adminRef(manu, sam)));
    await assertFails(deleteDoc(adminRef(sam, 'other')));
  });

  it('should take the powers away once the console removes « admins »', async () => {
    await seed(env, `admins/${manu}`, { ...superAdminDoc(), global: ['centres'] });

    await assertFails(setDoc(adminRef(manu, 'nina'), nina()));
    await assertFails(getDocs(collection(phoneOf(env, manu), 'admins')));
  });

  it('should give the super admin no power over a secteur from « admins » alone', async () => {
    await seed(env, `admins/${manu}`, { global: ['admins', 'centres'] });
    // Manu is no member of the 12, which only an admin of its CS reads.
    await seed(env, 'sectors/t12', sectorDoc({ number: 12, joinCode: 'M4N8RT', createdBy: lea }));

    await assertFails(getDoc(doc(phoneOf(env, manu), 'sectors/t12')));
    await assertFails(
      getDocs(query(collection(phoneOf(env, manu), 'sectors'), where('centreKey', 'in', ['villefranche']))),
    );
  });
});

describe('what an admin outside the team reads', () => {
  it('should let them read the secteur, its members, campaign and streets', async () => {
    const phone = phoneOf(env, sam);
    await assertSucceeds(getDoc(doc(phone, sectorPath)));
    await assertSucceeds(getDocs(collection(phone, `${sectorPath}/members`)));
    await assertSucceeds(getDoc(memberOf(sam, paul)));
    await assertSucceeds(getDoc(doc(phone, campaignPath)));
    await assertSucceeds(getDocs(collection(phone, streetsPath)));
  });

  it('should let only an admin of the CS list its secteurs', async () => {
    const ofVillefranche = (uid) =>
      query(collection(phoneOf(env, uid), 'sectors'), where('centreKey', 'in', ['villefranche']));
    await assertSucceeds(getDocs(ofVillefranche(sam)));
    await assertFails(getDocs(ofVillefranche(lea)));
    await assertFails(getDocs(ofVillefranche(zoe)));
    // Every secteur of the app, as the app did before PLAN §5.23: it could
    // hold another CS's, refused whole.
    await assertFails(getDocs(collection(phoneOf(env, sam), 'sectors')));
  });

  it('should refuse someone who is no longer an admin', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), `admins/${sam}`)),
    );

    await assertFails(getDoc(doc(phoneOf(env, sam), sectorPath)));
    await assertFails(getDocs(collection(phoneOf(env, sam), 'sectors')));
  });
});

describe('what an admin outside the team writes in the streets', () => {
  const nationale = (uid) => doc(phoneOf(env, uid), `${streetsPath}/nationale`);

  it('should let them mark a house, stamped with their own uid', async () => {
    await assertSucceeds(
      updateFields(nationale(sam), [
        [['houses', '4bis', 'status'], 'DONE'],
        [['houses', '4bis', 'comeBack'], null],
        [['houses', '4bis', 'by'], sam],
        [['houses', '4bis', 'at'], threePm],
      ]),
    );
  });

  it('should refuse a mark stamped with someone else’s uid', async () => {
    await assertFails(
      updateFields(nationale(sam), [
        [['houses', '4bis', 'status'], 'DONE'],
        [['houses', '4bis', 'comeBack'], null],
        [['houses', '4bis', 'by'], lea],
        [['houses', '4bis', 'at'], threePm],
      ]),
    );
  });

  it('should let them add a street and send one to the Corbeille', async () => {
    await assertSucceeds(
      setDoc(doc(phoneOf(env, sam), `${streetsPath}/paix`), newStreetDoc()),
    );
    await assertSucceeds(
      updateDoc(nationale(sam), { deletedAt: threePm, deletedBy: sam }),
    );
  });

  it('should let them purge a street past its 30 days in the Corbeille', async () => {
    await seed(
      env,
      `${streetsPath}/vieille`,
      streetDoc({ deletedAt: at('2020-01-01T10:00:00Z'), deletedBy: lea }),
    );

    await assertSucceeds(deleteDoc(doc(phoneOf(env, sam), `${streetsPath}/vieille`)));
  });

  it('should let a member put back a number an admin outside the team had removed', async () => {
    // The undo of « Restaurer » writes back the removal it undoes, here an
    // admin's who is not in the team (PLAN §6.2).
    await seed(
      env,
      `${streetsPath}/nationale`,
      streetDoc({ houses: { 4: houseEntry(4) } }),
    );

    await assertSucceeds(
      updateFields(nationale(lea), [
        [['houses', '4', 'deletedAt'], threePm],
        [['houses', '4', 'deletedBy'], sam],
      ]),
    );
  });

  it('should refuse someone outside who is not an admin', async () => {
    await assertFails(
      updateFields(nationale(zoe), [
        [['houses', '4bis', 'status'], 'DONE'],
        [['houses', '4bis', 'comeBack'], null],
        [['houses', '4bis', 'by'], zoe],
        [['houses', '4bis', 'at'], threePm],
      ]),
    );
    await assertFails(
      setDoc(doc(phoneOf(env, zoe), `${streetsPath}/paix`), newStreetDoc()),
    );
  });
});

describe('what an admin outside the team does to the members', () => {
  const acceptance = (by) => ({ status: 'active', acceptedBy: by, acceptedAt: threePm });

  it('should let them accept a request, in their own name', async () => {
    await assertSucceeds(updateDoc(memberOf(sam, paul), acceptance(sam)));
  });

  it('should refuse an acceptance in someone else’s name', async () => {
    await assertFails(updateDoc(memberOf(sam, paul), acceptance(manu)));
  });

  it('should let them refuse a request', async () => {
    await assertSucceeds(deleteDoc(memberOf(sam, paul)));
  });

  it('should let them remove an active member, an admin too', async () => {
    await assertSucceeds(deleteDoc(memberOf(sam, lea)));
    await assertSucceeds(deleteDoc(memberOf(sam, manu)));
  });

  it('should refuse a member who is not an admin removing an admin', async () => {
    await assertFails(deleteDoc(memberOf(lea, manu)));
  });

  it('should refuse them renaming a member', async () => {
    await assertFails(updateDoc(memberOf(sam, lea), { displayName: 'Léa B.' }));
  });
});

describe('an admin joining (« Rejoindre » of the banner)', () => {
  /** Sam's own document, already active, accepted by himself. */
  const joining = (overrides = {}) => activeMemberDoc('Sam', sam, overrides);

  it('should let an admin create their own document, active, without a code, '
    + 'holding their name', async () => {
    await assertSucceeds(writeWithName(phoneOf(env, sam), sam, joining(), 'sam'));
  });

  it('should refuse it without holding the name', async () => {
    await assertFails(setDoc(memberOf(sam, sam), joining()));
  });

  it('should refuse it under a name a member holds', async () => {
    // « LÉA » is Léa's name, case and accents ignored.
    await assertFails(
      writeWithName(phoneOf(env, sam), sam, joining({ displayName: 'LÉA' }), 'lea'),
    );
  });

  it('should refuse it accepted by someone else', async () => {
    await assertFails(setDoc(memberOf(sam, sam), joining({ acceptedBy: manu })));
  });

  it('should refuse it for someone else', async () => {
    await assertFails(setDoc(memberOf(sam, zoe), activeMemberDoc('Zoé', sam)));
  });

  it('should refuse it with another field or a name not cleaned', async () => {
    await assertFails(setDoc(memberOf(sam, sam), joining({ joinCode: code })));
    await assertFails(setDoc(memberOf(sam, sam), joining({ displayName: ' Sam' })));
  });

  it('should refuse someone who is not an admin', async () => {
    await assertFails(setDoc(memberOf(zoe, zoe), activeMemberDoc('Zoé', zoe)));
  });
});

describe('what an admin outside the team does to the secteur', () => {
  /** [uid] replaces K7P2QX by R2D2XY, as the adapter's transaction does. */
  function newCode(uid) {
    const db = phoneOf(env, uid);
    return runTransaction(db, async (transaction) => {
      await transaction.get(doc(db, 'joinCodes', 'R2D2XY'));
      transaction.update(doc(db, sectorPath), { joinCode: 'R2D2XY' });
      transaction.delete(doc(db, 'joinCodes', code));
      transaction.set(doc(db, 'joinCodes', 'R2D2XY'), previewDoc());
    });
  }

  /** The adapter's deletion: contents first, then the last batch. */
  async function deleteAll(uid, members = [manu, lea, paul]) {
    const db = phoneOf(env, uid);
    const contents = writeBatch(db);
    contents.delete(doc(db, `${streetsPath}/nationale`));
    contents.delete(doc(db, `${roundsPath}/round1`));
    contents.delete(doc(db, campaignPath));
    await contents.commit();
    const last = writeBatch(db);
    last.delete(doc(db, `joinCodes/${code}`));
    last.delete(doc(db, 'sectorKeys/villefranche_49'));
    last.delete(doc(db, sectorPath));
    for (const member of members) last.delete(doc(db, memberPath(member)));
    // The names they held (#148): an admin frees them whoever held them.
    for (const key of ['manu', 'lea', 'paul']) last.delete(doc(db, namePath(key)));
    return last.commit();
  }

  it('should let them replace the code', async () => {
    await assertSucceeds(newCode(sam));
  });

  it('should refuse a member who is not an admin replacing the code', async () => {
    await assertFails(newCode(lea));
  });

  it('should let them delete the secteur and everything in it', async () => {
    await assertSucceeds(deleteAll(sam));
  });

  it('should let them delete a secteur whose members all left', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      for (const member of [manu, lea, paul]) {
        await deleteDoc(doc(context.firestore(), memberPath(member)));
      }
    });

    await assertSucceeds(deleteAll(sam, []));
  });

  it('should refuse someone who is not an admin deleting the secteur', async () => {
    await assertFails(deleteAll(lea));
  });
});

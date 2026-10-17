// The administrators of the app (PLAN §5.12, the « Admins » block of
// §8.2): an `admins/{uid}` document added by hand in the console makes a
// phone an admin of every tournée, member of it or not. Sam is an admin
// in no tournée; Manu, who created Tournée 49, is one too; Léa is a
// member who is not.
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  runTransaction,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import {
  activeMemberDoc,
  at,
  campaignPath,
  code,
  houseEntry,
  lea,
  manu,
  memberPath,
  paul,
  phoneOf,
  previewDoc,
  rulesEnvironment,
  sam,
  seed,
  seedTeam,
  streetDoc,
  streetsPath,
  threePm,
  tourneePath,
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

describe('what an admin outside the team reads', () => {
  it('should let them read the tournée, its members, campaign and streets', async () => {
    const phone = phoneOf(env, sam);
    await assertSucceeds(getDoc(doc(phone, tourneePath)));
    await assertSucceeds(getDocs(collection(phone, `${tourneePath}/members`)));
    await assertSucceeds(getDoc(memberOf(sam, paul)));
    await assertSucceeds(getDoc(doc(phone, campaignPath)));
    await assertSucceeds(getDocs(collection(phone, streetsPath)));
  });

  it('should let only an admin list the tournées', async () => {
    await assertSucceeds(getDocs(collection(phoneOf(env, sam), 'tournees')));
    await assertFails(getDocs(collection(phoneOf(env, lea), 'tournees')));
    await assertFails(getDocs(collection(phoneOf(env, zoe), 'tournees')));
  });

  it('should refuse someone who is no longer an admin', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), `admins/${sam}`)),
    );

    await assertFails(getDoc(doc(phoneOf(env, sam), tourneePath)));
    await assertFails(getDocs(collection(phoneOf(env, sam), 'tournees')));
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
      setDoc(doc(phoneOf(env, sam), `${streetsPath}/paix`), streetDoc({ name: 'Rue de la Paix' })),
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
      setDoc(doc(phoneOf(env, zoe), `${streetsPath}/paix`), streetDoc({ name: 'Rue de la Paix' })),
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

  it('should let an admin create their own document, active, without a code', async () => {
    await assertSucceeds(setDoc(memberOf(sam, sam), joining()));
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

describe('what an admin outside the team does to the tournée', () => {
  /** [uid] replaces K7P2QX by R2D2XY, as the adapter's transaction does. */
  function newCode(uid) {
    const db = phoneOf(env, uid);
    return runTransaction(db, async (transaction) => {
      await transaction.get(doc(db, 'joinCodes', 'R2D2XY'));
      transaction.update(doc(db, tourneePath), { joinCode: 'R2D2XY' });
      transaction.delete(doc(db, 'joinCodes', code));
      transaction.set(doc(db, 'joinCodes', 'R2D2XY'), previewDoc());
    });
  }

  /** The adapter's deletion: contents first, then the last batch. */
  async function deleteAll(uid, members = [manu, lea, paul]) {
    const db = phoneOf(env, uid);
    const contents = writeBatch(db);
    contents.delete(doc(db, `${streetsPath}/nationale`));
    contents.delete(doc(db, campaignPath));
    await contents.commit();
    const last = writeBatch(db);
    last.delete(doc(db, `joinCodes/${code}`));
    last.delete(doc(db, 'tourneeKeys/villefranche_49'));
    last.delete(doc(db, tourneePath));
    for (const member of members) last.delete(doc(db, memberPath(member)));
    return last.commit();
  }

  it('should let them replace the code', async () => {
    await assertSucceeds(newCode(sam));
  });

  it('should refuse a member who is not an admin replacing the code', async () => {
    await assertFails(newCode(lea));
  });

  it('should let them delete the tournée and everything in it', async () => {
    await assertSucceeds(deleteAll(sam));
  });

  it('should let them delete a tournée whose members all left', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      for (const member of [manu, lea, paul]) {
        await deleteDoc(doc(context.firestore(), memberPath(member)));
      }
    });

    await assertSucceeds(deleteAll(sam, []));
  });

  it('should refuse someone who is not an admin deleting the tournée', async () => {
    await assertFails(deleteAll(lea));
  });
});

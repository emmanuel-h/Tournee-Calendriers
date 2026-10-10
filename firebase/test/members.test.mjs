// The members of a tournée (PLAN §8.1, §8.2): a newcomer's request, what a
// pending member may read, accepting, refusing, removing, leaving.
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
  campaignPath,
  lea,
  manu,
  memberPath,
  paul,
  phoneOf,
  requestDoc,
  rulesEnvironment,
  seedTeam,
  threePm,
  tourneePath,
  zoe,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-members');
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
});

/** The member document of [member], as [uid]'s phone sees it. */
const memberOf = (uid, member) => doc(phoneOf(env, uid), memberPath(member));

/** What accepting [member] writes (acceptanceFields). */
const acceptance = (by) => ({ status: 'active', acceptedBy: by, acceptedAt: threePm });

describe('a request to join', () => {
  const request = (uid, data) => setDoc(memberOf(uid, uid), data);

  it('should accept a pending request made with the current code', async () => {
    await assertSucceeds(request(zoe, requestDoc('Zoé')));
  });

  it('should refuse a request made with another code', async () => {
    await assertFails(request(zoe, requestDoc('Zoé', { joinCode: 'ABCDEF' })));
  });

  it('should refuse a request for someone else', async () => {
    await assertFails(setDoc(memberOf(zoe, 'marc'), requestDoc('Marc')));
  });

  it('should refuse a request that makes itself active', async () => {
    await assertFails(request(zoe, requestDoc('Zoé', { status: 'active' })));
  });

  it('should refuse a request that says it was accepted', async () => {
    await assertFails(request(zoe, requestDoc('Zoé', { acceptedBy: lea })));
    await assertFails(request(zoe, requestDoc('Zoé', { acceptedAt: threePm })));
  });

  it('should refuse a request whose time is not a timestamp', async () => {
    await assertFails(request(zoe, requestDoc('Zoé', { requestedAt: '2026-11-02' })));
  });

  it('should refuse a request when not signed in', async () => {
    await assertFails(setDoc(doc(phoneOf(env, null), memberPath(zoe)), requestDoc('Zoé')));
  });

  it('should refuse a request to a tournée that does not exist', async () => {
    await assertFails(
      setDoc(doc(phoneOf(env, zoe), `tournees/t50/members/${zoe}`), requestDoc('Zoé')),
    );
  });

  it('should accept a name of 30 characters and refuse 31', async () => {
    await assertSucceeds(request(zoe, requestDoc('🚒'.repeat(30))));
    await env.clearFirestore();
    await seedTeam(env);
    await assertFails(request(zoe, requestDoc('🚒'.repeat(31))));
  });

  it('should refuse a name that is blank or not cleaned', async () => {
    for (const name of ['', ' Zoé', 'Zoé ', 'Zoé  M.']) {
      await assertFails(request(zoe, requestDoc(name)));
    }
  });

  it('should refuse a field a member document does not have', async () => {
    await assertFails(request(zoe, { ...requestDoc('Zoé'), phone: '0600000000' }));
  });

  it('should refuse replacing a request that exists', async () => {
    await assertFails(request(paul, requestDoc('Paulo')));
  });
});

describe('what a pending member reads', () => {
  it('should let them read their own member document', async () => {
    await assertSucceeds(getDoc(memberOf(paul, paul)));
  });

  it('should let them read their own document once it is gone', async () => {
    // « Demande envoyée » follows it: refused means the document is gone.
    await assertSucceeds(getDoc(memberOf(zoe, zoe)));
  });

  it('should refuse them the tournée, the members, the campaign', async () => {
    const phone = phoneOf(env, paul);
    await assertFails(getDoc(doc(phone, tourneePath)));
    await assertFails(getDoc(memberOf(paul, manu)));
    await assertFails(getDocs(collection(phone, `${tourneePath}/members`)));
    await assertFails(getDoc(doc(phone, campaignPath)));
  });

  it('should let an active member read the tournée and list the members', async () => {
    const phone = phoneOf(env, lea);
    await assertSucceeds(getDoc(doc(phone, tourneePath)));
    await assertSucceeds(getDocs(collection(phone, `${tourneePath}/members`)));
    await assertSucceeds(getDoc(doc(phone, campaignPath)));
  });

  it('should refuse someone outside the tournée', async () => {
    await assertFails(getDoc(doc(phoneOf(env, zoe), tourneePath)));
    await assertFails(getDoc(memberOf(zoe, manu)));
  });

  it('should refuse listing the tournées', async () => {
    await assertFails(getDocs(collection(phoneOf(env, lea), 'tournees')));
  });
});

describe('accepting', () => {
  it('should let any active member accept a pending one', async () => {
    await assertSucceeds(updateDoc(memberOf(lea, paul), acceptance(lea)));
  });

  it('should refuse a pending member accepting themself', async () => {
    await assertFails(updateDoc(memberOf(paul, paul), acceptance(paul)));
  });

  it('should refuse an acceptance in someone else’s name', async () => {
    await assertFails(updateDoc(memberOf(lea, paul), acceptance(manu)));
  });

  it('should refuse accepting again a member already active', async () => {
    // It would rewrite who accepted them.
    await assertFails(updateDoc(memberOf(lea, manu), acceptance(lea)));
  });

  it('should refuse an acceptance that leaves the member pending', async () => {
    await assertFails(
      updateDoc(memberOf(lea, paul), { acceptedBy: lea, acceptedAt: threePm }),
    );
  });

  it('should refuse an acceptance time that is not a timestamp', async () => {
    await assertFails(
      updateDoc(memberOf(lea, paul), { ...acceptance(lea), acceptedAt: 'now' }),
    );
  });

  it('should refuse an acceptance that changes the name too', async () => {
    await assertFails(
      updateDoc(memberOf(lea, paul), { ...acceptance(lea), displayName: 'Paulo' }),
    );
  });

  it('should refuse any other change of a member', async () => {
    await assertFails(updateDoc(memberOf(lea, lea), { displayName: 'Léa B.' }));
    await assertFails(updateDoc(memberOf(manu, lea), { status: 'pending' }));
  });
});

describe('refusing, cancelling, removing, leaving', () => {
  it('should let an active member refuse a request', async () => {
    await assertSucceeds(deleteDoc(memberOf(lea, paul)));
  });

  it('should let the newcomer cancel their own request', async () => {
    await assertSucceeds(deleteDoc(memberOf(paul, paul)));
  });

  it('should refuse someone outside deleting a request', async () => {
    await assertFails(deleteDoc(memberOf(zoe, paul)));
  });

  it('should let the creator remove an active member', async () => {
    await assertSucceeds(deleteDoc(memberOf(manu, lea)));
  });

  it('should refuse an active member removing another', async () => {
    await assertSucceeds(updateDoc(memberOf(lea, paul), acceptance(lea)));

    await assertFails(deleteDoc(memberOf(lea, paul)));
  });

  it('should let an active member leave', async () => {
    await assertSucceeds(deleteDoc(memberOf(lea, lea)));
  });

  it('should refuse a pending member removing an active one', async () => {
    await assertFails(deleteDoc(memberOf(paul, lea)));
  });

  it('should refuse the creator leaving while the tournée exists', async () => {
    await assertFails(deleteDoc(memberOf(manu, manu)));
  });

  it('should refuse anyone removing the creator', async () => {
    await assertFails(deleteDoc(memberOf(lea, manu)));
  });
});

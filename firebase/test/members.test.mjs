// The members of a secteur (PLAN §8.1, §8.2): a newcomer's request, what a
// pending member may read, accepting, renaming oneself, refusing, removing,
// leaving.
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
  sectorPath,
  writeWithName,
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
  /** The request alone, without the name it holds (#148). */
  const request = (uid, data) => setDoc(memberOf(uid, uid), data);

  it('should accept a pending request made with the current code, holding '
    + 'its name', async () => {
    await assertSucceeds(
      writeWithName(phoneOf(env, zoe), zoe, requestDoc('Zoé'), 'zoe'),
    );
  });

  it('should refuse a request that does not hold its name', async () => {
    await assertFails(request(zoe, requestDoc('Zoé')));
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

  it('should refuse a request to a secteur that does not exist', async () => {
    await assertFails(
      setDoc(doc(phoneOf(env, zoe), `sectors/t50/members/${zoe}`), requestDoc('Zoé')),
    );
  });

  it('should accept a name of 30 characters and refuse 31', async () => {
    const phone = phoneOf(env, zoe);
    await assertSucceeds(
      writeWithName(phone, zoe, requestDoc('🚒'.repeat(30)), '🚒'.repeat(30)),
    );
    await env.clearFirestore();
    await seedTeam(env);
    await assertFails(
      writeWithName(phone, zoe, requestDoc('🚒'.repeat(31)), '🚒'.repeat(31)),
    );
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

  it('should refuse them the secteur, the members, the campaign', async () => {
    const phone = phoneOf(env, paul);
    await assertFails(getDoc(doc(phone, sectorPath)));
    await assertFails(getDoc(memberOf(paul, manu)));
    await assertFails(getDocs(collection(phone, `${sectorPath}/members`)));
    await assertFails(getDoc(doc(phone, campaignPath)));
  });

  it('should let an active member read the secteur and list the members', async () => {
    const phone = phoneOf(env, lea);
    await assertSucceeds(getDoc(doc(phone, sectorPath)));
    await assertSucceeds(getDocs(collection(phone, `${sectorPath}/members`)));
    await assertSucceeds(getDoc(doc(phone, campaignPath)));
  });

  it('should refuse someone outside the secteur', async () => {
    await assertFails(getDoc(doc(phoneOf(env, zoe), sectorPath)));
    await assertFails(getDoc(memberOf(zoe, manu)));
  });

  it('should refuse listing the secteurs', async () => {
    await assertFails(getDocs(collection(phoneOf(env, lea), 'sectors')));
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
    await assertFails(updateDoc(memberOf(manu, lea), { status: 'pending' }));
    await assertFails(updateDoc(memberOf(lea, lea), { requestedAt: threePm }));
  });
});

describe('renaming oneself', () => {
  /** What renaming writes (displayNameFields), without the name's entry. */
  const rename = (uid, member, name) =>
    updateDoc(memberOf(uid, member), { displayName: name });

  /** The rename of [uid] to [name] holding it under [key] (#148). */
  const renameHolding = (uid, name, key) =>
    writeWithName(phoneOf(env, uid), uid, { displayName: name }, key, {
      update: true,
    });

  it('should let an active member rename themself', async () => {
    await assertSucceeds(renameHolding(lea, 'Léa B.', 'lea b'));
  });

  it('should let the creator rename themself', async () => {
    await assertSucceeds(renameHolding(manu, 'Emmanuel', 'emmanuel'));
  });

  it('should refuse a rename that does not hold the new name', async () => {
    await assertFails(rename(lea, lea, 'Léa B.'));
  });

  it('should refuse renaming someone else, even as the creator', async () => {
    await assertFails(rename(lea, manu, 'Chef'));
    await assertFails(rename(manu, lea, 'Léa B.'));
  });

  it('should refuse a pending member renaming themself', async () => {
    await assertFails(rename(paul, paul, 'Paulo'));
  });

  it('should refuse someone outside renaming a member', async () => {
    await assertFails(rename(zoe, lea, 'Zoé'));
  });

  it('should accept a name of 30 characters and refuse 31', async () => {
    await assertSucceeds(renameHolding(lea, '🚒'.repeat(30), '🚒'.repeat(30)));
    await assertFails(renameHolding(lea, '🚒'.repeat(31), '🚒'.repeat(31)));
  });

  it('should refuse a name that is blank or not cleaned', async () => {
    for (const name of ['', ' Léa', 'Léa ', 'Léa  B.']) {
      await assertFails(rename(lea, lea, name));
    }
  });

  it('should refuse a rename that changes another field too', async () => {
    await assertFails(
      updateDoc(memberOf(lea, lea), { displayName: 'Léa B.', status: 'pending' }),
    );
    await assertFails(
      updateDoc(memberOf(lea, lea), { displayName: 'Léa B.', acceptedBy: lea }),
    );
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

  it('should let an admin, here the creator, remove an active member', async () => {
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

  it('should let the creator leave, the secteur going on', async () => {
    // The creator has no power of their own any more (PLAN §5.12).
    await assertSucceeds(deleteDoc(memberOf(manu, manu)));
  });

  it('should refuse a member who is not an admin removing the creator', async () => {
    await assertFails(deleteDoc(memberOf(lea, manu)));
  });
});

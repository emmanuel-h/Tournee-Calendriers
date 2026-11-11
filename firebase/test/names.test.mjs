// The names held in a secteur (#148, PLAN §5.16): `sectors/{id}/names/{key}`,
// one per member, under the key the domain makes of the name
// (MemberName.key): unique within a secteur, case and accents ignored.
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
  writeBatch,
} from 'firebase/firestore';
import {
  activeMemberDoc,
  lea,
  manu,
  memberPath,
  nameDoc,
  namePath,
  paul,
  phoneOf,
  requestDoc,
  rulesEnvironment,
  sam,
  seed,
  seedTeam,
  writeWithName,
  zoe,
} from './support.mjs';

let env;

before(async () => {
  env = await rulesEnvironment('demo-names');
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
});

/** The entry of key [key], as [uid]'s phone sees it. */
const entryOf = (uid, key) => doc(phoneOf(env, uid), namePath(key));

/** Zoé's request to join under [name], holding it under [key]. */
const requestAs = (name, key) =>
  writeWithName(phoneOf(env, zoe), zoe, requestDoc(name), key);

describe('the key of a name', () => {
  for (const [name, key] of [
    ['Zoé', 'zoe'],
    ['ZOÉ', 'zoe'],
    ['Zoé', 'zoe'],
    ['Zoé B.', 'zoe b'],
    ['Jean-Paul', 'jean paul'],
    ["N'Golo", 'n golo'],
    ['N’Golo', 'n golo'],
    ['Œdipe Ærø', 'oedipe aerø'],
    ['Ça Ñandú', 'ca nandu'],
    ['Zoé_B/2', 'zoe b 2'],
    ['🚒 Zoé', '🚒 zoe'],
    ['ÀÂÄÁÃÅ ÉÈÊË ÎÏÍÌ', 'aaaaaa eeee iiii'],
    ['ÔÖÓÒÕ ÙÛÜÚ ŸÝ', 'ooooo uuuu yy'],
    // `lower()` lowers A to Z only, as the app's key does (#148).
    ['ZØ', 'zØ'],
    ['ΣΑΜ', 'ΣΑΜ'],
  ]) {
    it(`should hold « ${name} » under « ${key} »`, async () => {
      await assertSucceeds(requestAs(name, key));
    });
  }

  it('should refuse a key that is not the name\'s', async () => {
    await assertFails(requestAs('Zoé', 'zoé'));
    await assertFails(requestAs('Zoé', 'zoe2'));
    await assertFails(requestAs('Zoé B.', 'zoe b.'));
  });
});

describe('a name another member holds', () => {
  it('should refuse a request under it, case and accents ignored', async () => {
    // `lea` is Léa's: creating it again is an update, refused.
    await assertFails(requestAs('LEA', 'lea'));
    await assertFails(requestAs('Léa', 'lea'));
  });

  it('should refuse a rename to it', async () => {
    await assertFails(
      writeWithName(phoneOf(env, lea), lea, { displayName: 'Manu' }, 'manu', {
        update: true,
      }),
    );
  });

  it('should refuse a request whose entry names someone else', async () => {
    const db = phoneOf(env, zoe);
    const batch = writeBatch(db);
    batch.set(doc(db, memberPath(zoe)), requestDoc('Zoé'));
    batch.set(doc(db, namePath('zoe')), nameDoc(sam));
    await assertFails(batch.commit());
  });

  it('should refuse an entry with anything but its member', async () => {
    const db = phoneOf(env, zoe);
    const batch = writeBatch(db);
    batch.set(doc(db, memberPath(zoe)), requestDoc('Zoé'));
    batch.set(doc(db, namePath('zoe')), { ...nameDoc(zoe), phone: '0600000000' });
    await assertFails(batch.commit());
  });

  it('should refuse an entry no member document holds', async () => {
    await assertFails(setDoc(entryOf(zoe, 'zoe'), nameDoc(zoe)));
  });

  it('should let a member hold the name their document already has', async () => {
    // A member of before #148, whose name was never held.
    await seed(env, memberPath(sam), activeMemberDoc('Sam', manu));

    await assertSucceeds(setDoc(entryOf(sam, 'sam'), nameDoc(sam)));
  });

  it('should refuse replacing an entry, even one\'s own', async () => {
    await assertFails(setDoc(entryOf(lea, 'lea'), nameDoc(lea)));
    await assertFails(updateDoc(entryOf(lea, 'lea'), { member: lea }));
  });
});

describe('a name freed', () => {
  /** Deletes [member]'s document and the entry [key] as [uid], in a batch. */
  function deleteWithName(uid, member, key) {
    const db = phoneOf(env, uid);
    const batch = writeBatch(db);
    batch.delete(doc(db, memberPath(member)));
    batch.delete(doc(db, namePath(key)));
    return batch.commit();
  }

  it('should go with a request refused by an active member', async () => {
    await assertSucceeds(deleteWithName(lea, paul, 'paul'));
  });

  it('should go with a request cancelled', async () => {
    await assertSucceeds(deleteWithName(paul, paul, 'paul'));
  });

  it('should go with a member who leaves', async () => {
    await assertSucceeds(deleteWithName(lea, lea, 'lea'));
  });

  it('should go with a member an admin removes', async () => {
    await assertSucceeds(deleteWithName(manu, lea, 'lea'));
  });

  it('should go with a rename, the new name held instead', async () => {
    const db = phoneOf(env, lea);
    const batch = writeBatch(db);
    batch.update(doc(db, memberPath(lea)), { displayName: 'Léa B.' });
    batch.set(doc(db, namePath('lea b')), nameDoc(lea));
    batch.delete(doc(db, namePath('lea')));
    await assertSucceeds(batch.commit());
  });

  it('should let a member be removed whose name was never held', async () => {
    // A member of before #148: the entry is not there.
    await seed(env, memberPath(sam), activeMemberDoc('Sam', manu));

    await assertSucceeds(deleteWithName(manu, sam, 'sam'));
  });

  it('should be refused while its member still holds it', async () => {
    await assertFails(deleteDoc(entryOf(lea, 'manu')));
    await assertFails(deleteDoc(entryOf(zoe, 'lea')));
    // Léa's own, kept as her name: she would free it for another.
    await assertFails(deleteDoc(entryOf(lea, 'lea')));
  });

  it('should let an admin free any of them', async () => {
    await assertSucceeds(deleteDoc(entryOf(sam, 'lea')));
  });

  it('should let anyone free one its member no longer holds', async () => {
    await seed(env, namePath('zoe'), nameDoc(zoe));

    await assertSucceeds(deleteDoc(entryOf(lea, 'zoe')));
  });

  it('should refuse someone who is not signed in', async () => {
    await seed(env, namePath('zoe'), nameDoc(zoe));

    await assertFails(deleteDoc(doc(phoneOf(env, null), namePath('zoe'))));
  });
});

describe('reading the names', () => {
  it('should let the team and the admins read and list them', async () => {
    for (const uid of [lea, sam]) {
      await assertSucceeds(getDoc(entryOf(uid, 'manu')));
      await assertSucceeds(
        getDocs(collection(phoneOf(env, uid), 'sectors/t49/names')),
      );
    }
  });

  it('should let a newcomer ask for a free name, or their own', async () => {
    await assertSucceeds(getDoc(entryOf(zoe, 'zoe')));
    await assertSucceeds(getDoc(entryOf(paul, 'paul')));
  });

  it('should refuse a newcomer a name another member holds, and the '
    + 'list', async () => {
    await assertFails(getDoc(entryOf(zoe, 'lea')));
    await assertFails(getDoc(entryOf(paul, 'lea')));
    await assertFails(getDocs(collection(phoneOf(env, zoe), 'sectors/t49/names')));
  });

  it('should refuse someone who is not signed in', async () => {
    await assertFails(getDoc(doc(phoneOf(env, null), namePath('zoe'))));
  });
});

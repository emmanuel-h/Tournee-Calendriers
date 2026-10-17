// The streets of a campaign: who reads them, and every write of the table
// in PLAN §6.2, as FirestoreStreetRepository sends it (field paths by
// segments), plus what the rules refuse.
import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  deleteField,
  doc,
  getDoc,
  getDocs,
  setDoc,
  Timestamp,
} from 'firebase/firestore';
import {
  buildingEntry,
  doorEntry,
  houseEntry,
  lea,
  manu,
  paul,
  phoneOf,
  rulesEnvironment,
  seed,
  seedTeam,
  streetDoc,
  streetsPath,
  tourneeDoc,
  tourneePath,
  threePm,
  twoPm,
  updateFields,
  zoe,
} from './support.mjs';

const fire = '🚒';

let env;

before(async () => {
  env = await rulesEnvironment('demo-streets');
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedTeam(env);
});

/** Rue Nationale, as [uid]'s phone sees it. */
const nationale = (uid = lea) => doc(phoneOf(env, uid), `${streetsPath}/nationale`);

/** The fields a house mark writes (HouseMarked). */
const mark = (label, status, comeBack, by = lea, time = threePm) => [
  [['houses', label, 'status'], status],
  [['houses', label, 'comeBack'], comeBack],
  [['houses', label, 'by'], by],
  [['houses', label, 'at'], time],
];

/** The fields a door mark writes (DwellingMarked). */
const doorMark = (key, status, comeBack, by = lea) => [
  [['houses', '8', 'dwellings', key, 'status'], status],
  [['houses', '8', 'dwellings', key, 'comeBack'], comeBack],
  [['houses', '8', 'dwellings', key, 'by'], by],
  [['houses', '8', 'dwellings', key, 'at'], threePm],
];

describe('reading streets', () => {
  it('should let an active member read a street and list them', async () => {
    await assertSucceeds(getDoc(nationale(lea)));
    await assertSucceeds(getDocs(collection(phoneOf(env, lea), streetsPath)));
  });

  it('should refuse a pending member any street', async () => {
    await assertFails(getDoc(nationale(paul)));
    await assertFails(getDocs(collection(phoneOf(env, paul), streetsPath)));
  });

  it('should refuse someone outside the tournée and someone not signed in', async () => {
    await assertFails(getDoc(nationale(zoe)));
    await assertFails(getDoc(nationale(null)));
  });
});

describe('creating a street', () => {
  // Each write a new document: a second write to the same one would be
  // an update, checked by other rules.
  let count = 0;
  const newStreet = (uid, data) =>
    setDoc(doc(phoneOf(env, uid), `${streetsPath}/new${(count += 1)}`), data);

  it('should accept a street imported from the BAN by an active member', async () => {
    await assertSucceeds(newStreet(lea, streetDoc({ name: "Rue de la Paix" })));
  });

  it('should accept a street entered by hand, without BAN id', async () => {
    await assertSucceeds(newStreet(lea, streetDoc({ banId: null, houses: {} })));
  });

  it('should refuse a pending member, an outsider and the signed out', async () => {
    await assertFails(newStreet(paul, streetDoc()));
    await assertFails(newStreet(zoe, streetDoc()));
    await assertFails(newStreet(null, streetDoc()));
  });

  it('should refuse a street in a previous campaign', async () => {
    await seed(env, tourneePath, tourneeDoc({ currentCampaign: 2027 }));

    await assertFails(newStreet(lea, streetDoc()));
  });

  it('should refuse a field the street document does not have', async () => {
    await assertFails(newStreet(lea, { ...streetDoc(), note: 'Mme Martin' }));
    const { banId, ...withoutBanId } = streetDoc();
    await assertFails(newStreet(lea, withoutBanId));
  });

  it('should refuse a street already in the Corbeille', async () => {
    await assertFails(newStreet(lea, streetDoc({ deletedAt: twoPm, deletedBy: lea })));
  });

  it('should accept a name of 150 characters and refuse 151', async () => {
    await assertSucceeds(newStreet(lea, streetDoc({ name: fire.repeat(150) })));
    await assertFails(newStreet(lea, streetDoc({ name: fire.repeat(151) })));
  });

  it('should refuse a name that is blank, untrimmed or on two lines', async () => {
    for (const name of ['', ' ', ' Rue Nationale', 'Rue  Nationale', 'Rue\nNationale']) {
      await assertFails(newStreet(lea, streetDoc({ name })));
    }
  });

  it('should accept a BAN id of 1 to 100 characters, or none', async () => {
    await assertSucceeds(newStreet(lea, streetDoc({ banId: 'x'.repeat(100) })));
    await assertSucceeds(newStreet(lea, streetDoc({ banId: 'x' })));
    await assertFails(newStreet(lea, streetDoc({ banId: 'x'.repeat(101) })));
    await assertFails(newStreet(lea, streetDoc({ banId: '' })));
    await assertFails(newStreet(lea, streetDoc({ banId: 69264 })));
  });

  it('should refuse a commune code that is not an INSEE code', async () => {
    await assertSucceeds(newStreet(lea, streetDoc({ communeCode: '2A004' })));
    await assertFails(newStreet(lea, streetDoc({ communeCode: '6926' })));
    await assertFails(newStreet(lea, streetDoc({ communeCode: '2a004' })));
  });

  it('should refuse a blank commune name', async () => {
    await assertFails(newStreet(lea, streetDoc({ communeName: '' })));
  });

  it('should accept a large street moved from the phone whole', async () => {
    // « Les ajouter à la tournée » (PLAN §5.0) writes each street of the
    // phone as one new document: 1 500 numbers, all marked by the caller,
    // and a building of 500 doors. A new street's houses are not checked
    // one by one, so no bulk limit applies (the 1 MB document limit does,
    // far above this ≈ 300 kB).
    const houses = {};
    for (let n = 1; n <= 1500; n += 1) {
      houses[n] = houseEntry(n, { status: 'DONE', by: lea, at: twoPm });
    }
    const dwellings = {};
    const doors = [];
    for (let door = 1; door <= 500; door += 1) {
      dwellings[`A-${door}`] = doorEntry({ status: 'NOBODY_HOME', by: lea, at: twoPm });
      doors.push(String(door));
    }
    houses[2000] = buildingEntry({
      n: 2000,
      layout: [{ esc: 'A', floor: null, doors }],
      dwellings,
    });

    await assertSucceeds(newStreet(lea, streetDoc({ houses })));
  });

  it('should refuse a street whose houses are not a map', async () => {
    await assertFails(newStreet(lea, streetDoc({ houses: [] })));
  });

  it('should accept a street written before the map, without shape or assignees', async () => {
    const { shape, assignees, ...beforeTheMap } = streetDoc();

    await assertSucceeds(newStreet(lea, beforeTheMap));
  });

  it('should accept a street given to the caller (« Ajouter et me l’attribuer »)', async () => {
    await assertSucceeds(newStreet(lea, streetDoc({ assignees: [lea] })));
  });

  it('should refuse a new street given to someone else', async () => {
    await assertFails(newStreet(lea, streetDoc({ assignees: [manu] })));
    await assertFails(newStreet(lea, streetDoc({ assignees: [lea, manu] })));
    await assertFails(newStreet(lea, streetDoc({ assignees: lea })));
  });

  it('should accept a street without a line and refuse a shape that is not a list', async () => {
    await assertSucceeds(newStreet(lea, streetDoc({ shape: [] })));
    await assertFails(newStreet(lea, streetDoc({ shape: 'eguwGkrx[mQxH' })));
  });

  it('should accept a shape of 1 000 lines and refuse 1 001', async () => {
    const lines = (count) => Array.from({ length: count }, () => 'eguwGkrx[mQxH');

    await assertSucceeds(newStreet(lea, streetDoc({ shape: lines(1000) })));
    await assertFails(newStreet(lea, streetDoc({ shape: lines(1001) })));
  });
});

describe('who covers a street', () => {
  /** Rue Nationale covered by [assignees] (absent: written before the map). */
  const coveredBy = (assignees) => {
    const data = streetDoc({ assignees });
    if (assignees === undefined) delete data.assignees;
    return seed(env, `${streetsPath}/nationale`, data);
  };

  const take = (uid, member = uid) =>
    updateFields(nationale(uid), [[['assignees'], arrayUnion(member)]]);
  const release = (uid, member = uid) =>
    updateFields(nationale(uid), [[['assignees'], arrayRemove(member)]]);

  it('should let a member take a street nobody covers', async () => {
    await assertSucceeds(take(lea));

    const stored = await getDoc(nationale(lea));
    assert.deepEqual(stored.data().assignees, [lea]);
  });

  it('should let a member take a street a teammate covers (« La faire aussi »)', async () => {
    await coveredBy([manu]);

    await assertSucceeds(take(lea));
  });

  it('should let a member take a street written before the map', async () => {
    await coveredBy(undefined);

    await assertSucceeds(take(lea));
  });

  it('should let a member stop covering a street, the teammates staying', async () => {
    await coveredBy([manu, lea]);

    await assertSucceeds(release(lea));
  });

  it('should refuse to put a teammate on a street', async () => {
    await assertFails(take(lea, manu));
  });

  it('should refuse to take a teammate off a street', async () => {
    await coveredBy([manu, lea]);

    await assertFails(release(lea, manu));
  });

  it('should refuse the whole list written over the teammates', async () => {
    await coveredBy([manu]);

    await assertFails(updateFields(nationale(lea), [[['assignees'], [lea]]]));
    await assertFails(updateFields(nationale(lea), [[['assignees'], [manu, lea, lea]]]));
    await assertFails(updateFields(nationale(lea), [[['assignees'], 'lea']]));
  });

  it('should refuse a pending member and an outsider', async () => {
    await assertFails(take(paul));
    await assertFails(take(zoe));
  });

  it('should refuse any change of the shape', async () => {
    await assertFails(updateFields(nationale(), [[['shape'], []]]));
    await coveredBy(undefined);
    const { shape, ...beforeTheMap } = streetDoc();
    await seed(env, `${streetsPath}/nationale`, beforeTheMap);
    await assertFails(updateFields(nationale(), [[['shape'], ['eguwGkrx[mQxH']]]));
  });
});

describe('marking a house', () => {
  it('should accept the status, the hint and the stamp of the caller', async () => {
    await assertSucceeds(updateFields(nationale(), mark('4bis', 'DONE', null)));
    await assertSucceeds(updateFields(nationale(), mark('4bis', 'NOBODY_HOME', null)));
    await assertSucceeds(updateFields(nationale(), mark('4bis', 'COME_BACK', '')));
    await assertSucceeds(updateFields(nationale(), mark('4bis', 'TO_DO', null)));
  });

  it('should refuse a `by` that is not the caller', async () => {
    await assertFails(updateFields(nationale(lea), mark('4bis', 'DONE', null, manu)));
  });

  it('should refuse a mark that keeps a teammate’s stamp', async () => {
    await assertFails(
      updateFields(nationale(manu), [[['houses', '4', 'status'], 'NOBODY_HOME']]),
    );
  });

  it('should refuse an `at` that is not a timestamp', async () => {
    await assertFails(
      updateFields(nationale(), mark('4bis', 'DONE', null, lea, '2026-11-02T15:00:00Z')),
    );
  });

  it('should accept an `at` far from the server time, as a mark made offline', async () => {
    const lastWeek = twoPm.toMillis() - 7 * 24 * 3600 * 1000;
    await assertSucceeds(
      updateFields(nationale(), mark('4bis', 'DONE', null, lea, new Date(lastWeek))),
    );
  });

  it('should refuse a status that is not one of the four', async () => {
    await assertFails(updateFields(nationale(), mark('4bis', 'REFUSED', null)));
    await assertFails(updateFields(nationale(), mark('4bis', 'done', null)));
  });

  it('should refuse a hint on a house that is not « repasser »', async () => {
    await assertFails(updateFields(nationale(), mark('4bis', 'DONE', 'après 19h')));
  });

  it('should refuse « repasser » without its hint field', async () => {
    await assertFails(updateFields(nationale(), mark('4bis', 'COME_BACK', null)));
  });

  it('should accept a hint of 20 characters and refuse 21, counted as code points', async () => {
    await assertSucceeds(updateFields(nationale(), mark('4bis', 'COME_BACK', fire.repeat(20))));
    await assertFails(updateFields(nationale(), mark('4bis', 'COME_BACK', fire.repeat(21))));
    await assertSucceeds(updateFields(nationale(), mark('4bis', 'COME_BACK', 'a'.repeat(20))));
    await assertFails(updateFields(nationale(), mark('4bis', 'COME_BACK', 'a'.repeat(21))));
  });

  it('should refuse a hint that is not trimmed', async () => {
    await assertFails(updateFields(nationale(), mark('4bis', 'COME_BACK', ' après 19h')));
    await assertFails(updateFields(nationale(), mark('4bis', 'COME_BACK', 'après 19h\n')));
  });

  it('should accept setting the hint alone (ComeBackSet)', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        [['houses', '6', 'comeBack'], 'samedi'],
        [['houses', '6', 'by'], lea],
        [['houses', '6', 'at'], threePm],
      ]),
    );
  });

  it('should refuse a `note` field on a house', async () => {
    await assertFails(
      updateFields(nationale(), [
        ...mark('4bis', 'DONE', null),
        [['houses', '4bis', 'note'], 'chien méchant'],
      ]),
    );
  });

  it('should refuse a change of the number or the position of a house', async () => {
    await assertFails(
      updateFields(nationale(), [...mark('4bis', 'DONE', null), [['houses', '4bis', 'n'], 5]]),
    );
    await assertFails(
      updateFields(nationale(), [...mark('4bis', 'DONE', null), [['houses', '4bis', 'lat'], 46]]),
    );
  });

  it('should refuse two houses marked in one write', async () => {
    await assertFails(
      updateFields(nationale(), [...mark('4bis', 'DONE', null), ...mark('4', 'DONE', null)]),
    );
  });

  it('should refuse a mark on a number that is no longer there', async () => {
    // A mark queued offline that reaches the server after a teammate
    // renumbered the house: it would leave a house entry without `n`.
    await assertFails(updateFields(nationale(), mark('2', 'DONE', null)));
  });

  it('should refuse a pending member and someone outside the tournée', async () => {
    await assertFails(updateFields(nationale(paul), mark('4bis', 'DONE', null, paul)));
    await assertFails(updateFields(nationale(zoe), mark('4bis', 'DONE', null, zoe)));
  });

  it('should refuse a member removed from the tournée', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), `${tourneePath}/members/${lea}`)),
    );

    await assertFails(updateFields(nationale(lea), mark('4bis', 'DONE', null)));
  });

  it('should refuse a mark in a previous campaign', async () => {
    await seed(env, tourneePath, tourneeDoc({ currentCampaign: 2027 }));

    await assertFails(updateFields(nationale(), mark('4bis', 'DONE', null)));
  });

  it('should mark a house among 400, a street as long as they come', async () => {
    const houses = {};
    for (let n = 1; n <= 400; n++) houses[n] = houseEntry(n);
    await seed(env, `${streetsPath}/longue`, streetDoc({ houses }));

    await assertSucceeds(
      updateFields(doc(phoneOf(env, lea), `${streetsPath}/longue`), mark('399', 'DONE', null)),
    );
  });
});

describe('tries with nobody home', () => {
  /** A mark with the tries it writes: a count, or the field removed. */
  const markWithTries = (label, status, tries, comeBack = null) => [
    ...mark(label, status, comeBack),
    [['houses', label, 'tries'], tries],
  ];

  it('should accept the first try and one more (« Repassé, toujours personne »)', async () => {
    await assertSucceeds(updateFields(nationale(), markWithTries('4bis', 'NOBODY_HOME', 1)));
    await assertSucceeds(updateFields(nationale(), markWithTries('4bis', 'NOBODY_HOME', 2)));
  });

  it('should accept the tries removed when the house is to do again', async () => {
    await updateFields(nationale(), markWithTries('4bis', 'NOBODY_HOME', 3));

    await assertSucceeds(
      updateFields(nationale(), markWithTries('4bis', 'TO_DO', deleteField())),
    );
  });

  it('should accept 99 tries and refuse 0, 100 or tries that are not a whole number', async () => {
    await assertSucceeds(updateFields(nationale(), markWithTries('4bis', 'DONE', 99)));
    for (const tries of [0, 100, -1, 1.5, '2', null]) {
      await assertFails(updateFields(nationale(), markWithTries('4bis', 'NOBODY_HOME', tries)));
    }
  });

  it('should accept a mark of an older app that leaves the tries as they were', async () => {
    await updateFields(nationale(), markWithTries('4bis', 'NOBODY_HOME', 3));

    await assertSucceeds(updateFields(nationale(), mark('4bis', 'TO_DO', null)));
  });

  it('should accept the tries of a door and refuse them out of range', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        ...doorMark('A0-Gauche', 'NOBODY_HOME', null),
        [['houses', '8', 'dwellings', 'A0-Gauche', 'tries'], 2],
      ]),
    );
    await assertFails(
      updateFields(nationale(), [
        ...doorMark('A0-Gauche', 'NOBODY_HOME', null),
        [['houses', '8', 'dwellings', 'A0-Gauche', 'tries'], 100],
      ]),
    );
  });

  it('should accept a door put back whole with its tries by an undo', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        [
          ['houses', '8', 'dwellings', 'A0-Gauche'],
          doorEntry({ status: 'NOBODY_HOME', by: lea, at: threePm, tries: 2 }),
        ],
      ]),
    );
  });

  it('should accept a house renumbered with its tries', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        [['houses', '4bis'], deleteField()],
        [
          ['houses', '4ter'],
          houseEntry(4, { sfx: 'ter', status: 'NOBODY_HOME', by: lea, at: threePm, tries: 2 }),
        ],
      ]),
    );
  });

  it('should refuse a number added with tries', async () => {
    await assertFails(
      updateFields(nationale(), [[['houses', '20'], houseEntry(20, { tries: 1 })]]),
    );
  });
});

describe('a building', () => {
  it('should accept marking a door whose key holds a dot', async () => {
    await assertSucceeds(updateFields(nationale(), doorMark('A0-Porte 1.2', 'DONE', null)));
  });

  it('should accept the hint of a door « repasser », up to 20 characters', async () => {
    await assertSucceeds(
      updateFields(nationale(), doorMark('A0-Gauche', 'COME_BACK', fire.repeat(20))),
    );
    await assertFails(
      updateFields(nationale(), doorMark('A0-Gauche', 'COME_BACK', fire.repeat(21))),
    );
  });

  it('should refuse a door mark stamped with someone else', async () => {
    await assertFails(updateFields(nationale(lea), doorMark('A0-Gauche', 'DONE', null, manu)));
  });

  it('should refuse a `note` field on a door', async () => {
    await assertFails(
      updateFields(nationale(), [
        ...doorMark('A0-Gauche', 'DONE', null),
        [['houses', '8', 'dwellings', 'A0-Gauche', 'note'], 'digicode 1234'],
      ]),
    );
  });

  it('should refuse a door status that is not one of the four', async () => {
    await assertFails(updateFields(nationale(), doorMark('A0-Gauche', 'GONE', null)));
  });

  it('should refuse two doors marked in one write', async () => {
    await assertFails(
      updateFields(nationale(), [
        ...doorMark('A0-Gauche', 'NOBODY_HOME', null),
        ...doorMark('A0-Porte 1.2', 'DONE', null),
      ]),
    );
  });

  it('should refuse a mark on a door the layout no longer has', async () => {
    await assertFails(updateFields(nationale(), doorMark('A1-Droite', 'DONE', null)));
  });

  it('should accept a door put back whole by an undo (DwellingReverted)', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        [['houses', '8', 'dwellings', 'A0-Gauche'], doorEntry({ by: lea, at: threePm })],
      ]),
    );
  });

  it('should mark a door of a building of 500 doors', async () => {
    const dwellings = {};
    for (let i = 1; i <= 500; i++) dwellings[`A-${i}`] = doorEntry();
    await seed(
      env,
      `${streetsPath}/tour`,
      streetDoc({
        houses: {
          8: buildingEntry({
            labelStyle: 'FLOOR_AND_NUMBER',
            layout: [{ esc: 'A', floor: null, doors: Object.keys(dwellings).map((k) => k.slice(2)) }],
            dwellings,
          }),
        },
      }),
    );

    await assertSucceeds(
      updateFields(doc(phoneOf(env, lea), `${streetsPath}/tour`), doorMark('A-250', 'DONE', null)),
    );
  });

  it('should accept the building’s own « repasser » and refuse a status of its own', async () => {
    const ownComeBack = (hint) =>
      updateFields(nationale(), [
        [['houses', '8', 'comeBack'], hint],
        [['houses', '8', 'by'], lea],
        [['houses', '8', 'at'], threePm],
      ]);
    await assertSucceeds(ownComeBack(fire.repeat(20)));
    await assertFails(ownComeBack(fire.repeat(21)));
    await assertSucceeds(ownComeBack(null));
    await assertFails(updateFields(nationale(), mark('8', 'DONE', null)));
  });

  it('should accept laying a house out as a building, door by door', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        ...mark('4bis', 'TO_DO', null),
        [['houses', '4bis', 'labelStyle'], 'FLOOR_AND_NUMBER'],
        [['houses', '4bis', 'layout'], [{ esc: 'A', floor: 0, doors: ['01', '02'] }]],
        [['houses', '4bis', 'dwellings', 'A0-01'], doorEntry()],
        [['houses', '4bis', 'dwellings', 'A0-02'], doorEntry()],
      ]),
    );
  });

  it('should accept a new layout that drops a door', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        ...mark('8', 'TO_DO', null),
        [['houses', '8', 'labelStyle'], 'FREE'],
        [['houses', '8', 'layout'], [{ esc: 'A', floor: 0, doors: ['Gauche'] }]],
        [['houses', '8', 'dwellings', 'A0-Gauche'], doorEntry({ status: 'DONE', by: lea, at: twoPm })],
        [['houses', '8', 'dwellings', 'A0-Porte 1.2'], deleteField()],
      ]),
    );
  });

  it('should refuse a building without doors or floors', async () => {
    await assertFails(
      updateFields(nationale(), [...mark('8', 'TO_DO', null), [['houses', '8', 'dwellings'], {}]]),
    );
    await assertFails(
      updateFields(nationale(), [...mark('8', 'TO_DO', null), [['houses', '8', 'layout'], []]]),
    );
  });

  it('should accept 500 doors and refuse 501', async () => {
    const layOut = (count) => {
      const labels = Array.from({ length: count }, (_, i) => `${i + 1}`);
      return updateFields(nationale(), [
        ...mark('4bis', 'TO_DO', null),
        [['houses', '4bis', 'labelStyle'], 'FREE'],
        [['houses', '4bis', 'layout'], [{ esc: 'A', floor: null, doors: labels }]],
        ...labels.map((label) => [['houses', '4bis', 'dwellings', `A-${label}`], doorEntry()]),
      ]);
    };

    await assertFails(layOut(501));
    await assertSucceeds(layOut(500));
  });

  it('should accept 26 staircases of floors 0 to 50 and refuse one row more', async () => {
    const rows = (count) =>
      Array.from({ length: count }, (_, i) => ({
        esc: String.fromCharCode(65 + Math.floor(i / 51)),
        floor: 50 - (i % 51),
        doors: [],
      }));
    const layOut = (count) =>
      updateFields(nationale(), [...mark('8', 'TO_DO', null), [['houses', '8', 'layout'], rows(count)]]);

    await assertFails(layOut(26 * 51 + 1));
    await assertSucceeds(layOut(26 * 51));
  });

  it('should refuse a building written whole with a field it does not have', async () => {
    await assertFails(
      updateFields(nationale(), [
        [['houses', '8'], deleteField()],
        [['houses', '8bis'], { ...buildingEntry({ sfx: 'bis', by: lea, at: threePm }), note: 'x' }],
      ]),
    );
  });

  it('should refuse a label style that is not one of the three', async () => {
    await assertFails(
      updateFields(nationale(), [
        ...mark('8', 'TO_DO', null),
        [['houses', '8', 'labelStyle'], 'ROMAN'],
      ]),
    );
  });

  it('should refuse a layout stamped with someone else', async () => {
    await assertFails(
      updateFields(nationale(lea), [
        ...mark('8', 'TO_DO', null, manu),
        [['houses', '8', 'layout'], [{ esc: 'A', floor: 0, doors: ['Gauche'] }]],
      ]),
    );
  });

  it('should accept a building turned back into a single house', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        ...mark('8', 'COME_BACK', ''),
        [['houses', '8', 'labelStyle'], deleteField()],
        [['houses', '8', 'layout'], deleteField()],
        [['houses', '8', 'dwellings'], deleteField()],
      ]),
    );
  });

  it('should refuse a building left without its doors', async () => {
    await assertFails(
      updateFields(nationale(), [
        ...mark('8', 'TO_DO', null),
        [['houses', '8', 'dwellings'], deleteField()],
      ]),
    );
  });
});

describe('numbers', () => {
  it('should accept numbers added, each a new unmarked house', async () => {
    await assertSucceeds(updateFields(nationale(), [[['houses', '10'], houseEntry(10)]]));
    await assertSucceeds(
      updateFields(nationale(), [
        [['houses', '12'], houseEntry(12, { lat: null, lon: null })],
        [['houses', '12A'], houseEntry(12, { sfx: 'a' })],
      ]),
    );
  });

  it('should accept the largest number and refuse one above', async () => {
    await assertSucceeds(updateFields(nationale(), [[['houses', '99999'], houseEntry(99999)]]));
    await assertFails(updateFields(nationale(), [[['houses', '100000'], houseEntry(100000)]]));
  });

  it('should refuse a number added under a key that is not its label', async () => {
    await assertFails(updateFields(nationale(), [[['houses', '11'], houseEntry(10)]]));
    await assertFails(
      updateFields(nationale(), [[['houses', '12a'], houseEntry(12, { sfx: 'a' })]]),
    );
    await assertFails(
      updateFields(nationale(), [[['houses', '12BIS'], houseEntry(12, { sfx: 'bis' })]]),
    );
  });

  it('should refuse a number added already marked, or with a `note`', async () => {
    await assertFails(
      updateFields(nationale(), [
        [['houses', '10'], houseEntry(10, { status: 'DONE', by: lea, at: threePm })],
      ]),
    );
    await assertFails(
      updateFields(nationale(), [[['houses', '10'], { ...houseEntry(10), note: 'x' }]]),
    );
  });

  it('should refuse a number added in the Corbeille, or with half a stamp', async () => {
    await assertFails(
      updateFields(nationale(), [
        [['houses', '10'], houseEntry(10, { deletedAt: threePm, deletedBy: lea })],
      ]),
    );
    await assertFails(
      updateFields(nationale(), [[['houses', '10'], houseEntry(10, { at: threePm })]]),
    );
    await assertFails(
      updateFields(nationale(), [[['houses', '10'], houseEntry(10, { by: lea })]]),
    );
  });

  it('should refuse a suffix that is not lowercase letters and digits', async () => {
    await assertFails(
      updateFields(nationale(), [[['houses', '10B'], houseEntry(10, { sfx: 'B' })]]),
    );
  });

  it('should refuse a position outside the Earth', async () => {
    await assertFails(
      updateFields(nationale(), [[['houses', '10'], houseEntry(10, { lat: 91 })]]),
    );
    await assertFails(
      updateFields(nationale(), [[['houses', '10'], houseEntry(10, { lat: 45.9, lon: null })]]),
    );
  });

  it('should accept 500 numbers added at once and refuse 501', async () => {
    const added = (count) =>
      Array.from({ length: count }, (_, i) => [['houses', `${1000 + i}`], houseEntry(1000 + i)]);

    await assertFails(updateFields(nationale(), added(501)));
    await assertSucceeds(updateFields(nationale(), added(500)));
  });

  it('should refuse numbers added and an existing house changed in one write', async () => {
    // The adapter sends each number restored from the Corbeille on its own.
    await assertFails(
      updateFields(nationale(), [
        [['houses', '10'], houseEntry(10)],
        [['houses', '14ter', 'deletedAt'], null],
        [['houses', '14ter', 'deletedBy'], null],
      ]),
    );
  });

  it('should accept a number removed by the caller, and restored', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        [['houses', '4', 'deletedAt'], threePm],
        [['houses', '4', 'deletedBy'], lea],
      ]),
    );
    await assertSucceeds(
      updateFields(nationale(), [
        [['houses', '14', 'deletedAt'], null],
        [['houses', '14', 'deletedBy'], null],
      ]),
    );
  });

  it('should accept a teammate’s removal put back by the undo of « Restaurer »', async () => {
    await assertSucceeds(
      updateFields(nationale(lea), [
        [['houses', '4', 'deletedAt'], twoPm],
        [['houses', '4', 'deletedBy'], manu],
      ]),
    );
  });

  it('should refuse a removal naming someone not active in the tournée', async () => {
    for (const someone of [paul, zoe]) {
      await assertFails(
        updateFields(nationale(lea), [
          [['houses', '4', 'deletedAt'], twoPm],
          [['houses', '4', 'deletedBy'], someone],
        ]),
      );
    }
  });

  it('should refuse half a removal stamp, or a removal time that is no time', async () => {
    await assertFails(updateFields(nationale(), [[['houses', '14', 'deletedBy'], null]]));
    await assertFails(updateFields(nationale(), [[['houses', '4', 'deletedAt'], threePm]]));
    await assertFails(
      updateFields(nationale(lea), [
        [['houses', '4', 'deletedAt'], '2026-11-02'],
        [['houses', '4', 'deletedBy'], manu],
      ]),
    );
  });

  it('should accept a house renumbered, stamped by the caller', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        [['houses', '8'], deleteField()],
        [['houses', '8bis'], buildingEntry({ sfx: 'bis', by: lea, at: threePm })],
      ]),
    );
  });

  it('should refuse a renumbered house stamped with someone else', async () => {
    await assertFails(
      updateFields(nationale(lea), [
        [['houses', '4'], deleteField()],
        [['houses', '5'], houseEntry(5, { status: 'DONE', by: manu, at: threePm })],
      ]),
    );
  });

  it('should refuse a renumbered house sent to the Corbeille', async () => {
    await assertFails(
      updateFields(nationale(), [
        [['houses', '4'], deleteField()],
        [['houses', '5'], houseEntry(5, { status: 'DONE', by: lea, at: threePm, deletedAt: threePm, deletedBy: lea })],
      ]),
    );
  });

  it('should refuse a renumbered house under a key that is not its label', async () => {
    await assertFails(
      updateFields(nationale(), [
        [['houses', '4'], deleteField()],
        [['houses', '5'], houseEntry(4, { status: 'DONE', by: lea, at: threePm })],
      ]),
    );
  });

  it('should refuse houses deleted outright', async () => {
    await assertFails(updateFields(nationale(), [[['houses', '4'], deleteField()]]));
  });
});

describe('the street itself', () => {
  it('should accept a new name and refuse one of 151 characters', async () => {
    await assertSucceeds(updateFields(nationale(), [[['name'], 'Rue de la République']]));
    await assertSucceeds(updateFields(nationale(), [[['name'], fire.repeat(150)]]));
    await assertFails(updateFields(nationale(), [[['name'], fire.repeat(151)]]));
  });

  it('should accept the street sent to the Corbeille by the caller and restored', async () => {
    await assertSucceeds(
      updateFields(nationale(), [
        [['deletedAt'], threePm],
        [['deletedBy'], lea],
      ]),
    );
    await assertSucceeds(
      updateFields(nationale(), [
        [['deletedAt'], null],
        [['deletedBy'], null],
      ]),
    );
  });

  it('should refuse a deletion stamped with someone else', async () => {
    await assertFails(
      updateFields(nationale(lea), [
        [['deletedAt'], threePm],
        [['deletedBy'], manu],
      ]),
    );
  });

  it('should refuse a change of the commune, the BAN id or a new field', async () => {
    await assertFails(updateFields(nationale(), [[['communeCode'], '2A004']]));
    await assertFails(updateFields(nationale(), [[['banId'], '69264_0001']]));
    await assertFails(updateFields(nationale(), [[['note'], 'x']]));
  });

  it('should let only the creator delete a street outright', async () => {
    await assertFails(deleteDoc(nationale(lea)));
    await assertSucceeds(deleteDoc(nationale(manu)));
  });
});

describe('the 30-day purge of the Corbeille', () => {
  const day = 24 * 60 * 60 * 1000;
  const minute = 60 * 1000;

  /** A time [ms] before now, as the emulator's clock reads it. */
  const ago = (ms) => Timestamp.fromMillis(Date.now() - ms);

  /** Rue Nationale with house 14 removed by Léa at [removedAt]. */
  const seedRemoved = (removedAt) =>
    seed(env, `${streetsPath}/nationale`, {
      ...streetDoc(),
      houses: {
        ...streetDoc().houses,
        14: houseEntry(14, { deletedAt: removedAt, deletedBy: lea }),
      },
    });

  /** Rue Nationale in the Corbeille since [deletedAt], by Manu. */
  const seedDeleted = (deletedAt, path = `${streetsPath}/nationale`) =>
    seed(env, path, streetDoc({ deletedAt, deletedBy: manu }));

  /** The purge of house 14 (NumbersPurged): its entry deleted. */
  const dropFourteen = (uid = lea) =>
    updateFields(nationale(uid), [[['houses', '14'], deleteField()]]);

  it('should let a member drop a number removed 31 days ago', async () => {
    await seedRemoved(ago(31 * day));
    await assertSucceeds(dropFourteen());
  });

  it('should refuse to drop a number removed 29 days ago', async () => {
    await seedRemoved(ago(29 * day));
    await assertFails(dropFourteen());
  });

  it('should refuse a number just short of 30 days and accept it just past', async () => {
    await seedRemoved(ago(30 * day - minute));
    await assertFails(dropFourteen());
    await seedRemoved(ago(30 * day + minute));
    await assertSucceeds(dropFourteen());
  });

  it('should refuse to drop a number restored meanwhile', async () => {
    await seedRemoved(null);
    await assertFails(dropFourteen());
  });

  it('should refuse two numbers dropped in one write', async () => {
    await seed(env, `${streetsPath}/nationale`, {
      ...streetDoc(),
      houses: {
        ...streetDoc().houses,
        14: houseEntry(14, { deletedAt: ago(40 * day), deletedBy: lea }),
        '14ter': houseEntry(14, { sfx: 'ter', deletedAt: ago(40 * day), deletedBy: lea }),
      },
    });
    await assertFails(
      updateFields(nationale(), [
        [['houses', '14'], deleteField()],
        [['houses', '14ter'], deleteField()],
      ]),
    );
  });

  it('should refuse a number dropped with another change in the same write', async () => {
    await seedRemoved(ago(31 * day));
    await assertFails(
      updateFields(nationale(), [
        [['houses', '14'], deleteField()],
        ...mark('4', 'NOBODY_HOME', null),
      ]),
    );
  });

  it('should refuse a pending member and someone outside the tournée', async () => {
    await seedRemoved(ago(31 * day));
    await assertFails(dropFourteen(paul));
    await assertFails(dropFourteen(zoe));
  });

  it('should let a member remove a street deleted 31 days ago', async () => {
    await seedDeleted(ago(31 * day));
    await assertSucceeds(deleteDoc(nationale(lea)));
  });

  it('should refuse to remove a street deleted 29 days ago', async () => {
    await seedDeleted(ago(29 * day));
    await assertFails(deleteDoc(nationale(lea)));
  });

  it('should refuse a street just short of 30 days and accept it just past', async () => {
    await seedDeleted(ago(30 * day - minute));
    await assertFails(deleteDoc(nationale(lea)));
    await seedDeleted(ago(30 * day + minute));
    await assertSucceeds(deleteDoc(nationale(lea)));
  });

  it('should refuse to remove a street of the Corbeille for a pending member or an outsider', async () => {
    await seedDeleted(ago(31 * day));
    await assertFails(deleteDoc(nationale(paul)));
    await assertFails(deleteDoc(nationale(zoe)));
  });

  it('should leave a previous campaign to the start of a new one', async () => {
    const old = `${tourneePath}/campaigns/2025/streets/nationale`;
    await seedDeleted(ago(40 * day), old);
    await assertFails(deleteDoc(doc(phoneOf(env, lea), old)));
  });
});

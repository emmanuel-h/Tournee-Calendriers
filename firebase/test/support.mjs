// What every rules test file shares: the emulator environment, the team of
// Tournée 49 of CS Villefranche, and documents shaped exactly as the Dart
// mappers write them (lib/infrastructure/firestore/mappers/, PLAN §6.2).
// When a mapper changes, the documents here change with it.
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  FieldPath,
  Timestamp,
  doc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

/**
 * A fresh environment on the emulator `firebase emulators:exec` started
 * (it sets FIRESTORE_EMULATOR_HOST). Each test file passes its own
 * [projectId]: `node --test` runs the files at the same time, and two
 * projects never see each other's documents.
 */
export function rulesEnvironment(projectId) {
  return initializeTestEnvironment({
    projectId,
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    },
  });
}

/** The phone of [uid], signed in anonymously; `null` for no sign-in. */
export function phoneOf(env, uid) {
  return uid === null
    ? env.unauthenticatedContext().firestore()
    : env.authenticatedContext(uid).firestore();
}

/** Writes [data] at [path] as an administrator would, past the rules. */
export function seed(env, path, data) {
  return env.withSecurityRulesDisabled((context) =>
    setDoc(doc(context.firestore(), path), data),
  );
}

/**
 * An update naming its fields by segments, as the Dart adapter does
 * (`FieldPath(['houses', '8', 'dwellings', 'A0-Porte 1.2', 'status'])`):
 * [fields] is a list of `[segments, value]`.
 */
export function updateFields(ref, fields) {
  const args = fields.flatMap(([segments, value]) => [
    new FieldPath(...segments),
    value,
  ]);
  return updateDoc(ref, ...args);
}

/** A time stored as the Dart mappers store it: a Firestore Timestamp. */
export const at = (iso) => Timestamp.fromDate(new Date(iso));

export const twoPm = at('2026-11-02T14:00:00Z');
export const threePm = at('2026-11-02T15:00:00Z');

// The team: Manu created the tournée, Léa was accepted, Paul is waiting
// for an answer, Zoé is in no tournée. Manu is an administrator of the app
// (`admins/manu`, PLAN §5.12), and so is Sam, who is in no tournée.
export const manu = 'manu';
export const lea = 'lea';
export const paul = 'paul';
export const zoe = 'zoe';
export const sam = 'sam';

export const sectorId = 't49';
export const code = 'K7P2QX';
export const sectorPath = `sectors/${sectorId}`;
export const campaignPath = `${sectorPath}/campaigns/2026`;
export const streetsPath = `${campaignPath}/streets`;
export const roundsPath = `${campaignPath}/rounds`;
export const memberPath = (uid) => `${sectorPath}/members/${uid}`;

/** communeEntry of Villefranche-sur-Saône, with its centre. */
export const villefrancheEntry = {
  code: '69264',
  name: 'Villefranche-sur-Saône',
  lat: 45.9837,
  lon: 4.726,
};

/** communeEntry of Gleizé, its neighbour, with its centre. */
export const gleizeEntry = {
  code: '69092',
  name: 'Gleizé',
  lat: 45.9915,
  lon: 4.6883,
};

/** [count] different communes of the Rhône (69001…), without centre. */
export const communeEntries = (count) =>
  Array.from({ length: count }, (_, i) => ({
    code: `69${String(i + 1).padStart(3, '0')}`,
    name: `Commune ${i + 1}`,
    lat: null,
    lon: null,
  }));

/** sectorToDocument. */
export const sectorDoc = (overrides = {}) => ({
  number: 49,
  centreKey: 'villefranche',
  centreName: 'CS Villefranche',
  joinCode: code,
  createdBy: manu,
  createdAt: twoPm,
  currentCampaign: 2026,
  communes: [villefrancheEntry],
  ...overrides,
});

/** memberToDocument of an active member. */
export const activeMemberDoc = (name, acceptedBy, overrides = {}) => ({
  displayName: name,
  status: 'active',
  requestedAt: twoPm,
  acceptedBy,
  acceptedAt: threePm,
  ...overrides,
});

/** joinRequestDocument: a pending member and the code used. */
export const requestDoc = (name, overrides = {}) => ({
  displayName: name,
  status: 'pending',
  requestedAt: threePm,
  acceptedBy: null,
  acceptedAt: null,
  joinCode: code,
  ...overrides,
});

/** joinCodeDocument. */
export const previewDoc = (overrides = {}) => ({
  sectorId,
  number: 49,
  centreName: 'CS Villefranche',
  campaign: 2026,
  ...overrides,
});

/** firstCampaignDocument. */
export const campaignDoc = () => ({ startedAt: twoPm, previousYear: null });

/** houseEntry of a single house, unmarked unless [overrides] says. */
export const houseEntry = (n, overrides = {}) => ({
  n,
  sfx: null,
  lat: 45.98915,
  lon: 4.71862,
  status: 'TO_DO',
  comeBack: null,
  by: null,
  at: null,
  deletedAt: null,
  deletedBy: null,
  ...overrides,
});

/** dwellingEntry. */
export const doorEntry = (overrides = {}) => ({
  status: 'TO_DO',
  comeBack: null,
  by: null,
  at: null,
  ...overrides,
});

/**
 * houseEntry of building 8: staircase A, a ground floor of two doors
 * (one with a free label holding a dot) and an emptied first floor.
 */
export const buildingEntry = (overrides = {}) => ({
  ...houseEntry(8),
  labelStyle: 'FREE',
  layout: [
    { esc: 'A', floor: 1, doors: [] },
    { esc: 'A', floor: 0, doors: ['Gauche', 'Porte 1.2'] },
  ],
  dwellings: {
    'A0-Gauche': doorEntry({ status: 'DONE', by: lea, at: twoPm }),
    'A0-Porte 1.2': doorEntry(),
  },
  ...overrides,
});

/** streetToDocument of Rue Nationale, imported from the BAN. */
export const streetDoc = (overrides = {}) => ({
  name: 'Rue Nationale',
  communeName: 'Villefranche-sur-Saône',
  communeCode: '69264',
  banId: '69264_0420',
  deletedAt: null,
  deletedBy: null,
  // Where it runs (one encoded polyline per piece of road), from the map
  // (T3.3).
  shape: ['eguwGkrx[mQxH'],
  houses: {
    4: houseEntry(4, { status: 'DONE', by: lea, at: twoPm }),
    '4bis': houseEntry(4, { sfx: 'bis' }),
    // « Repasser » with the free hint an app of before #81 wrote.
    6: houseEntry(6, {
      status: 'COME_BACK',
      comeBack: 'après 19h',
      by: lea,
      at: twoPm,
    }),
    8: buildingEntry(),
    14: houseEntry(14, { deletedAt: twoPm, deletedBy: lea }),
    '14ter': houseEntry(14, {
      sfx: 'ter',
      deletedAt: twoPm,
      deletedBy: lea,
    }),
  },
  ...overrides,
});

/**
 * The most houses one write may add (`housesPerWrite` in the rules and in
 * lib/infrastructure/firestore/mappers/street_writes.dart, #70).
 */
export const housesPerWrite = 2;

/**
 * The first write of Rue de la Paix just imported from the BAN: the street
 * with its first houses (as many as one write may add), unmarked.
 */
export const newStreetDoc = (overrides = {}) =>
  streetDoc({
    name: 'Rue de la Paix',
    banId: '69264_0610',
    houses: { 4: houseEntry(4), '4bis': houseEntry(4, { sfx: 'bis' }) },
    ...overrides,
  });

/**
 * Writes the street [data] at [ref] as the adapter writes a new street:
 * the document with its first houses (one when it is held in part, #138),
 * then the others in updates of housesPerWrite, in order. Rejects at the
 * first write refused.
 */
export async function writeInChunks(ref, data) {
  const entries = Object.entries(data.houses);
  const inFirst = 'part' in data ? 1 : housesPerWrite;
  const first = Object.fromEntries(entries.slice(0, inFirst));
  await setDoc(ref, { ...data, houses: first });
  for (let start = inFirst; start < entries.length; start += housesPerWrite) {
    await updateFields(
      ref,
      entries
        .slice(start, start + housesPerWrite)
        .map(([label, house]) => [['houses', label], house]),
    );
  }
}

/**
 * roundToDocument of a validated tournée of an afternoon: 23 houses, 19
 * dons, 2 calendars given for free. No member, no don.
 */
export const roundDoc = (overrides = {}) => ({
  startedAt: at('2026-10-24T12:05:00Z'),
  endedAt: at('2026-10-24T16:20:00Z'),
  housesVisited: 23,
  free: 2,
  cash: { count: 15, cents: 21000 },
  cheque: { count: 3, cents: 6000 },
  card: { count: 1, cents: 1000 },
  ...overrides,
});

/**
 * Stores the team of Tournée 49 as the adapters leave it after creating
 * it, accepting Léa and receiving Paul's request, with Rue Nationale and
 * a validated tournée in the campaign 2026; and the two administrators,
 * added by hand in the console (no fields).
 */
export async function seedTeam(env) {
  await seed(env, `admins/${manu}`, {});
  await seed(env, `admins/${sam}`, {});
  await seed(env, sectorPath, sectorDoc());
  await seed(env, memberPath(manu), activeMemberDoc('Manu', manu));
  await seed(env, memberPath(lea), {
    ...activeMemberDoc('Léa', manu),
    joinCode: code,
  });
  await seed(env, memberPath(paul), requestDoc('Paul'));
  await seed(env, campaignPath, campaignDoc());
  await seed(env, `joinCodes/${code}`, previewDoc());
  await seed(env, 'sectorKeys/villefranche_49', { sectorId });
  await seed(env, 'rescueCentres/villefranche', { name: 'CS Villefranche' });
  await seed(env, `${streetsPath}/nationale`, streetDoc());
  await seed(env, `${roundsPath}/round1`, roundDoc());
}

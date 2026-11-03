// One-off migration of the Firestore data from the names of 0.9.0 and
// older to those of the code since #116 (PLAN §6.2):
//
//   tournees/{id}/**     → sectors/{id}/**   (members, campaigns/{year}/streets…)
//   tourneeKeys/{key}    → sectorKeys/{key}
//   field `tourneeId`    → `sectorId`        (in sectorKeys and joinCodes)
//
// It goes past the security rules (firebase-admin), so it runs only on a
// trusted machine. Three modes:
//
//   node tool/migrate_to_sectors.mjs                 dry run: counts only
//   node tool/migrate_to_sectors.mjs --apply         copies to the new names
//   node tool/migrate_to_sectors.mjs --delete-old    copies, then deletes the
//                                                    old documents and fields
//
// Idempotent: a document already at its new name is never overwritten
// (the app may have changed it since the first run), and a second run only
// counts it as « already there ». The old documents stay until
// `--delete-old`, so the copy can be checked in the console first.
//
// Credentials are the caller's: Application Default Credentials
// (`gcloud auth application-default login`, or GOOGLE_APPLICATION_CREDENTIALS
// naming a service account key), or the emulator when FIRESTORE_EMULATOR_HOST
// is set. The project comes from `--project <id>` or GOOGLE_CLOUD_PROJECT.
import { pathToFileURL } from 'node:url';
import { FieldValue } from 'firebase-admin/firestore';

/** The name a field or collection has since #116. */
export const renamed = (name) =>
  name.replaceAll('Tournee', 'Sector').replaceAll('tournee', 'sector');

/** [data] with every top-level field named after a tournée renamed. */
export function renamedFields(data) {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [renamed(key), value]),
  );
}

/** Whether [data] has a field still named after a tournée. */
const hasOldField = (data) => Object.keys(data).some((key) => renamed(key) !== key);

const newCounts = () => ({ toCopy: 0, alreadyThere: 0, toDelete: 0 });

/**
 * Copies the tree of [from] (the document and every subcollection, at any
 * depth) to [to], each document only where [to] has none yet. A document
 * that does not exist but has subcollections (Firestore allows it) is
 * walked all the same.
 */
async function copyTree(from, to, counts, writer) {
  const [source, target] = await Promise.all([from.get(), to.get()]);
  if (source.exists) {
    if (target.exists) {
      counts.alreadyThere++;
    } else {
      counts.toCopy++;
      writer?.create(to, renamedFields(source.data()));
    }
  }
  for (const collection of await from.listCollections()) {
    for (const child of await collection.listDocuments()) {
      await copyTree(child, to.collection(renamed(collection.id)).doc(child.id), counts, writer);
    }
  }
}

/** How many documents (existing ones) the tree of [from] holds. */
async function countTree(from) {
  let count = (await from.get()).exists ? 1 : 0;
  for (const collection of await from.listCollections()) {
    for (const child of await collection.listDocuments()) count += await countTree(child);
  }
  return count;
}

/**
 * Migrates [db]. [apply]: write the copies; [deleteOld]: also delete the
 * old documents and fields (it implies [apply]). Returns the counts per
 * kind of document; in a dry run they say what a real run would do.
 */
export async function migrate(db, { apply = false, deleteOld = false } = {}) {
  const writes = apply || deleteOld;
  const counts = { sectors: newCounts(), sectorKeys: newCounts(), joinCodes: newCounts() };

  // The copies first, all of them, so nothing is deleted before its copy
  // is on the server.
  let writer = writes ? db.bulkWriter() : null;
  const oldSectors = await db.collection('tournees').listDocuments();
  for (const old of oldSectors) {
    await copyTree(old, db.collection('sectors').doc(old.id), counts.sectors, writer);
  }
  const oldKeys = await db.collection('tourneeKeys').get();
  for (const old of oldKeys.docs) {
    const target = db.collection('sectorKeys').doc(old.id);
    if ((await target.get()).exists) {
      counts.sectorKeys.alreadyThere++;
    } else {
      counts.sectorKeys.toCopy++;
      writer?.create(target, renamedFields(old.data()));
    }
  }
  // A join code keeps its document: only its fields get their new names,
  // the old ones beside them until --delete-old.
  const codes = await db.collection('joinCodes').get();
  for (const code of codes.docs) {
    const data = code.data();
    if (!hasOldField(data)) continue;
    const fresh = Object.fromEntries(
      Object.entries(renamedFields(data)).filter(([key]) => !(key in data)),
    );
    if (Object.keys(fresh).length === 0) {
      counts.joinCodes.alreadyThere++;
    } else {
      counts.joinCodes.toCopy++;
      writer?.update(code.ref, fresh);
    }
  }
  await writer?.close();

  for (const old of oldSectors) counts.sectors.toDelete += await countTree(old);
  counts.sectorKeys.toDelete = oldKeys.size;
  counts.joinCodes.toDelete = codes.docs.filter((code) => hasOldField(code.data())).length;
  if (deleteOld) {
    for (const old of oldSectors) await db.recursiveDelete(old);
    writer = db.bulkWriter();
    for (const old of oldKeys.docs) writer.delete(old.ref);
    for (const code of codes.docs) {
      const oldFields = Object.keys(code.data()).filter((key) => renamed(key) !== key);
      if (oldFields.length > 0) {
        writer.update(
          code.ref,
          Object.fromEntries(oldFields.map((key) => [key, FieldValue.delete()])),
        );
      }
    }
    await writer.close();
  }
  return counts;
}

/** The counts as lines a person reads, after a run in [mode]. */
export function report(counts, mode) {
  const copied = mode === 'dry-run' ? 'to copy' : 'copied';
  const deleted = mode === 'delete-old' ? 'old deleted' : 'old to delete with --delete-old';
  return Object.entries(counts).map(
    ([kind, { toCopy, alreadyThere, toDelete }]) =>
      `${kind}: ${toCopy} ${copied}, ${alreadyThere} already there, ${toDelete} ${deleted}`,
  );
}

async function main(args) {
  const deleteOld = args.includes('--delete-old');
  const apply = args.includes('--apply');
  const mode = deleteOld ? 'delete-old' : apply ? 'apply' : 'dry-run';
  const projectAt = args.indexOf('--project');
  const projectId = projectAt >= 0 ? args[projectAt + 1] : process.env.GOOGLE_CLOUD_PROJECT;
  if (!projectId) {
    console.error('Name the project: --project <id> (or GOOGLE_CLOUD_PROJECT).');
    process.exit(2);
  }
  // Imported here, so a test importing [migrate] does not start an app.
  const { initializeApp, applicationDefault } = await import('firebase-admin/app');
  const { getFirestore } = await import('firebase-admin/firestore');
  const app = process.env.FIRESTORE_EMULATOR_HOST
    ? initializeApp({ projectId })
    : initializeApp({ projectId, credential: applicationDefault() });
  const where = process.env.FIRESTORE_EMULATOR_HOST
    ? `emulator ${process.env.FIRESTORE_EMULATOR_HOST}`
    : 'the real project';
  console.log(`${mode} on ${projectId} (${where})`);
  const counts = await migrate(getFirestore(app), { apply, deleteOld });
  for (const line of report(counts, mode)) console.log(line);
  if (mode === 'dry-run') console.log('Nothing written. Run again with --apply to copy.');
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(process.argv.slice(2));
}

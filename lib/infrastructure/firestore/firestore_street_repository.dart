import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/pending_sync.dart';
import 'package:tournee_calendriers/application/ports/server_connection.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_update_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_writes.dart';
import 'package:tournee_calendriers/infrastructure/firestore/ordered_writes.dart';
import 'package:tournee_calendriers/infrastructure/firestore/street_memory.dart';

/// The [StreetRepository] of M2: the streets of one campaign of one
/// tournée, `tournees/{id}/campaigns/{year}/streets` (PLAN §6.2), shared by
/// the whole team. Also the [PendingSync] of those streets, and the
/// [ServerConnection] of the phone while the tournée is open.
///
/// - **One listener** on the whole collection (≈ 60 streets), started at the
///   first call: Firestore serves it from the phone's cache at once (an
///   offline cold start included, PLAN §7), then from the server whenever it
///   can. Every read is answered from what it gave ([StreetMemory]).
/// - **Memory first.** [add] and [save] put the street in memory and hand
///   the write to Firestore without waiting: Firestore applies it to the
///   phone's copy at once and sends it when the network allows, after a
///   restart if need be. See [sendInBackground].
/// - **In order per street** ([OrderedWrites]): the Firestore plugin may
///   hand two calls made back to back to the SDK the other way round, so a
///   write that needs the one before is sent only once the phone's copy
///   shows it, and the writes of a street wait for those asked before.
/// - **Field paths.** [save] writes only the fields the change names
///   (`houses.12.status`), so two people marking different houses never
///   overwrite each other ([streetUpdates]).
/// - **Undo** is stamped with who undoes, read from [IdentityProvider] and
///   [Clock] at the time of the write (PLAN §8.2).
final class FirestoreStreetRepository
    implements StreetRepository, PendingSync, ServerConnection {
  FirestoreStreetRepository(
    FirebaseFirestore db, {
    required TourneeId tournee,
    required CampaignYear campaign,
    // `this._identity` as a named parameter: callers write it without the
    // underscore, `identity:`.
    required this._identity,
    required this._clock,
  }) : _streets = FirestoreLayout.streetsOf(db, tournee, campaign);

  final CollectionReference<Map<String, dynamic>> _streets;
  final IdentityProvider _identity;
  final Clock _clock;

  StreetMemory? _memory;

  /// `late`: built at its first use, when `_streets` is set. The phone's
  /// copy of a street is its document's snapshots, metadata changes
  /// included so that this phone's own writes are told at once, offline
  /// too.
  late final _writes = OrderedWrites(
    copyOf: (id) => _streets
        .doc(id)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.data()),
    report: sendInBackground,
  );
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listener;

  /// The memory, listening from the first call on.
  StreetMemory get _ready => _memory ??= _listen();

  @override
  Future<Street?> find(StreetId id) async => (await _ready.streets())[id];

  @override
  Future<Street?> findByBanId(BanStreetId banId) async {
    for (final street in (await _ready.streets()).values) {
      if (street.banId == banId) return street;
    }
    return null;
  }

  @override
  Stream<Street?> watch(StreetId id) => _ready.observe(
    (streets) => streets[id],
    (changed) => changed.contains(id),
  );

  @override
  Stream<List<Street>> watchAll() => _ready.observe(
    (streets) => List.unmodifiable([
      for (final street in streets.values)
        if (!street.isDeleted) street,
    ]),
    (_) => true,
  );

  @override
  Stream<List<Street>> watchDeleted() => _ready.observe(
    (streets) => List.unmodifiable([
      for (final street in streets.values)
        if (street.isDeleted) street,
    ]),
    (_) => true,
  );

  @override
  Stream<int> watchUnsentStreets() => _ready.watchUnsent();

  /// Offline while the listener's snapshots come from the phone's copy:
  /// Firestore marks them `isFromCache` once it stops reaching the server,
  /// and sends a snapshot of metadata only when it reaches it again.
  @override
  Stream<bool> watchOffline() => _ready.watchOffline();

  /// Writes the document with its first houses, then the others a few per
  /// update ([newStreetWrites]): the security rules check each house a
  /// write adds, and only so many fit in one write (#70). Each update goes
  /// once the phone's copy holds the houses of the write before: sent
  /// before its document, it would be lost. This phone has the street
  /// whole in memory at once, and the writes follow in the background (a
  /// few milliseconds each); a teammate may see the street partly filled
  /// for a moment.
  @override
  Future<void> add(Street street) async {
    _ready.put(street);
    final id = street.id.value;
    final doc = _streets.doc(id);
    final writes = newStreetWrites(street);
    final first = (writes.document['houses']! as Map<String, Object?>).keys;
    _writes.send(id, 'add $id', [
      OrderedWrite(
        () => doc.set(writes.document),
        isShownIn: (copy) => holdsHouses(copy, first),
      ),
      for (final update in writes.updates)
        OrderedWrite(
          () => doc.update(update),
          isShownIn: (copy) => holdsHouses(copy, addedLabels(update)),
        ),
    ]);
  }

  @override
  Future<void> save(Street street, StreetChange change) async {
    _ready.put(street);
    final updates = streetUpdates(
      street,
      change,
      undoStamp: ChangeStamp(by: _identity.currentMember, at: _clock.now()),
      removal: FieldValue.delete(),
      arrayUnion: (item) => FieldValue.arrayUnion([item]),
      arrayRemove: (item) => FieldValue.arrayRemove([item]),
    );
    final doc = _streets.doc(street.id.value);
    // Behind the writes of the street still going (a street just added),
    // then all at once: when a change needs several updates (numbers
    // added, restored, purged), they touch different houses of a document
    // that exists, so their order does not matter.
    _writes.send(street.id.value, '$change', [
      for (final update in updates)
        OrderedWrite(
          () => doc.update({
            // A top-level field (`name`, `deletedAt`) is written as its
            // name: the same for Firestore, and the only form the
            // in-memory Firestore of the tests reads for one segment.
            // Those names are ours, without dots; the house and door paths
            // keep their segments.
            for (final MapEntry(:key, :value) in update.entries)
              (key.components.length == 1 ? key.components.single : key): value,
          }),
        ),
    ]);
  }

  /// Deletes the street's document, memory first. The security rules
  /// accept it only when its `deletedAt` is more than 30 days before the
  /// server's time; refused (a teammate restored it meanwhile), Firestore
  /// puts it back on this phone at the next snapshot.
  @override
  Future<void> purge(StreetId id) async {
    _ready.remove(id);
    _writes.send(id.value, 'purge ${id.value}', [
      OrderedWrite(() => _streets.doc(id.value).delete()),
    ]);
  }

  /// Stops listening: the composition root calls it when the tournée or
  /// the campaign changes.
  Future<void> close() async {
    await _listener?.cancel();
  }

  StreetMemory _listen() {
    final memory = StreetMemory();
    // `includeMetadataChanges`: a snapshot also comes when only
    // `hasPendingWrites` changes (the server received a write), which is
    // what the pending count needs, or `isFromCache` (the network went or
    // came back), which is what « offline » needs.
    _listener = _streets
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) => memory.receive(
            {
              for (final change in snapshot.docChanges)
                StreetId(
                  change.doc.id,
                ): change.type == DocumentChangeType.removed
                    ? null
                    : _read(change.doc),
            },
            {
              for (final doc in snapshot.docs)
                if (doc.metadata.hasPendingWrites) StreetId(doc.id),
            },
            fromCache: snapshot.metadata.isFromCache,
          ),
          onError: memory.fail,
        );
    return memory;
  }

  /// The street in [doc], or null when it cannot be read: it is left out
  /// rather than stopping the whole tournée, and kept in Firestore.
  Street? _read(DocumentSnapshot<Map<String, dynamic>> doc) {
    try {
      return streetFromDocument(doc.id, doc.data()!);
    } on FormatException catch (error) {
      debugPrint('Unreadable street ${doc.id}: $error');
      return null;
    }
  }
}

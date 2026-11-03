import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/pending_sync.dart';
import 'package:tournee_calendriers/application/ports/server_connection.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_update_mapper.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_writes.dart';
import 'package:tournee_calendriers/infrastructure/firestore/ordered_writes.dart';
import 'package:tournee_calendriers/infrastructure/firestore/street_memory.dart';
import 'package:tournee_calendriers/infrastructure/firestore/unfinished_streets.dart';

/// The [StreetRepository] of M2: the streets of one campaign of one
/// tournée, `sectors/{id}/campaigns/{year}/streets` (PLAN §6.2), shared by
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
/// - **Caught up after a kill** ([UnfinishedStreets]): a new street of
///   more houses than one write holds is kept on the phone until all its
///   writes are in Firestore's hands; at the next start, the houses missing
///   from the phone's copy are sent again (#104).
/// - **Undo** is stamped with who undoes, read from [IdentityProvider] and
///   [Clock] at the time of the write (PLAN §8.2).
final class FirestoreStreetRepository
    implements StreetRepository, PendingSync, ServerConnection {
  FirestoreStreetRepository(
    FirebaseFirestore db, {
    required SectorId sector,
    required CampaignYear campaign,
    // `this._identity` as a named parameter: callers write it without the
    // underscore, `identity:`.
    required this._identity,
    required this._clock,
    required this._unfinished,
  }) : _streets = FirestoreLayout.streetsOf(db, sector, campaign);

  final CollectionReference<Map<String, dynamic>> _streets;
  final IdentityProvider _identity;
  final Clock _clock;
  final UnfinishedStreets _unfinished;

  /// The whole document of each new street whose writes are still going,
  /// by id. Firestore shows such a street growing a few houses per write;
  /// read with the houses it misses taken from here, it stays whole on this
  /// phone ([withHousesOf]).
  final _whole = <String, Map<String, Object?>>{};

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
  ///
  /// When the street needs more than one write, it is first kept on the
  /// phone ([UnfinishedStreets]), and its writes start once it is: killed
  /// in the middle, the app finishes them at its next start (#104).
  @override
  Future<void> add(Street street) async {
    _ready.put(street);
    final writes = newStreetWrites(street);
    final chained = writes.updates.isNotEmpty;
    _sendNew(
      street,
      writes,
      what: 'add',
      kept: chained,
      after: chained ? _keep(street) : null,
    );
  }

  /// Keeps [street] on the phone for a catch-up. Its failure (a full disk)
  /// is only logged: the street is written all the same, only without the
  /// safety net.
  Future<void> _keep(Street street) => _unfinished
      .keep(street)
      .then<void>(
        (_) {},
        onError: (Object error) =>
            debugPrint('Street ${street.id.value} not kept: $error'),
      );

  /// Sends the [writes] of the new [street] in order, after [after]; while
  /// they go, this phone reads the street whole ([_whole]). Once they are
  /// over, forgets the street [kept] on the phone.
  ///
  /// In a debug build, logs how long the writes took, to measure a long
  /// street on a real phone: `flutter logs`, lines « Street … written ».
  void _sendNew(
    Street street,
    ({Map<String, Object?>? document, List<Map<FieldPath, Object?>> updates})
    writes, {
    required String what,
    required bool kept,
    Future<void>? after,
  }) {
    final id = street.id.value;
    final doc = _streets.doc(id);
    _whole[id] = streetToDocument(street);
    final ordered = [
      if (writes.document case final document?)
        OrderedWrite(
          () => doc.set(document),
          isShownIn: (copy) => holdsHouses(
            copy,
            (document['houses']! as Map<String, Object?>).keys,
          ),
        ),
      for (final update in writes.updates)
        OrderedWrite(
          () => doc.update(update),
          isShownIn: (copy) => holdsHouses(copy, addedLabels(update)),
        ),
    ];
    final took = Stopwatch()..start();
    _writes.send(
      id,
      '$what $id',
      ordered,
      after: after,
      whenOver: () {
        _whole.remove(id);
        if (kept) sendInBackground('forget $id', _unfinished.forget(street.id));
        if (kDebugMode) {
          final ms = took.elapsedMilliseconds;
          debugPrint(
            'Street $id written ($what): ${ordered.length} writes in $ms ms',
          );
        }
      },
    );
  }

  /// Finishes the new streets whose writes a kill of the app cut off
  /// (#104): for each one kept, sends what the phone's copy of its document
  /// is missing ([catchUpWrites]). The copy is the document's first
  /// snapshot, which Firestore serves from the phone at once, offline too.
  /// A failure (the storage unreadable, the tournée no longer readable) is
  /// only logged: the user can still add the missing numbers by hand.
  Future<void> _catchUp(StreetMemory memory) async {
    for (final street in await _unfinished.load()) {
      final id = street.id.value;
      // Read whole from now on, before its copy is even read.
      _whole[id] = streetToDocument(street);
      final copy = (await _streets.doc(id).snapshots().first).data();
      // Not even its document reached Firestore: the street is only here.
      if (copy == null) memory.put(street);
      _sendNew(
        street,
        catchUpWrites(street, copy),
        what: 'catch up',
        kept: true,
      );
    }
  }

  @override
  Future<void> save(Street street, StreetChange change) async {
    _ready.put(street);
    final updates = streetUpdates(
      street,
      change,
      undoStamp: ChangeStamp(by: _identity.currentMember, at: _clock.now()),
      removal: FieldValue.delete(),
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
    unawaited(
      _catchUp(memory).catchError(
        (Object error) => debugPrint('Streets not caught up: $error'),
      ),
    );
    return memory;
  }

  /// The street in [doc], or null when it cannot be read: it is left out
  /// rather than stopping the whole tournée, and kept in Firestore.
  Street? _read(DocumentSnapshot<Map<String, dynamic>> doc) {
    final stored = doc.data()!;
    try {
      return streetFromDocument(doc.id, switch (_whole[doc.id]) {
        final whole? => withHousesOf(stored, whole),
        null => stored,
      });
    } on FormatException catch (error) {
      debugPrint('Unreadable street ${doc.id}: $error');
      return null;
    }
  }
}

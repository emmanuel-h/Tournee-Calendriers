import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/ports/pending_sync.dart';
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
import 'package:tournee_calendriers/infrastructure/firestore/street_memory.dart';

/// The [StreetRepository] of M2: the streets of one campaign of one
/// tournée, `tournees/{id}/campaigns/{year}/streets` (PLAN §6.2), shared by
/// the whole team. Also the [PendingSync] of those streets.
///
/// - **One listener** on the whole collection (≈ 60 streets), started at the
///   first call: Firestore serves it from the phone's cache at once (an
///   offline cold start included, PLAN §7), then from the server whenever it
///   can. Every read is answered from what it gave ([StreetMemory]).
/// - **Memory first.** [add] and [save] put the street in memory and hand
///   the write to Firestore without waiting: Firestore applies it to the
///   phone's copy at once and sends it when the network allows, after a
///   restart if need be. See [sendInBackground].
/// - **Field paths.** [save] writes only the fields the change names
///   (`houses.12.status`), so two people marking different houses never
///   overwrite each other ([streetUpdates]).
/// - **Undo** is stamped with who undoes, read from [IdentityProvider] and
///   [Clock] at the time of the write (PLAN §8.2).
final class FirestoreStreetRepository implements StreetRepository, PendingSync {
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

  @override
  Future<void> add(Street street) async {
    _ready.put(street);
    sendInBackground(
      'add ${street.id.value}',
      _streets.doc(street.id.value).set(streetToDocument(street)),
    );
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
    // Sent one after the other: Firestore keeps the order of the writes of
    // one phone, offline too.
    for (final update in updates) {
      sendInBackground(
        '$change',
        doc.update({
          // A top-level field (`name`, `deletedAt`) is written as its name:
          // the same for Firestore, and the only form the in-memory
          // Firestore of the tests reads for one segment. Those names are
          // ours, without dots; the house and door paths keep their
          // segments.
          for (final MapEntry(:key, :value) in update.entries)
            (key.components.length == 1 ? key.components.single : key): value,
        }),
      );
    }
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
    // what the pending count needs.
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

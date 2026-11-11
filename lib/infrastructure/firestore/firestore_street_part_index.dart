import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tournee_calendriers/application/ports/street_part_index.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_parts_document_mapper.dart';

/// The [StreetPartIndex] over Firestore, for the open secteur [_sector]:
/// `streetParts/{banId}` (PLAN §6.2), one document per BAN street, an
/// entry per secteur.
///
/// - **Writes** merge the secteur's own entry into the document (a `set`
///   with `merge`), so two secteurs writing the same street at once keep
///   both entries, and the document is created by the first. Firestore
///   queues them on the phone, offline and across restarts, like the
///   street writes. Their `Future` is Firestore's own: it ends when the
///   server has the write and fails when the server refuses it, for the
///   caller to report (`IndexedStreetRepository`) or to wait for (a
///   secteur being deleted).
/// - **Reads** ask for one document by its id (the security rules allow
///   `get`, never `list`): from the server when it answers, else from the
///   phone's copy. Offline with no copy, or refused, it is none: the index
///   is only a hint. The rules let only an admin, or an active member of
///   the secteur named in their `openSectors/{uid}`, read it (#147):
///   [declareReader] names it.
final class FirestoreStreetPartIndex implements StreetPartIndex {
  FirestoreStreetPartIndex(
    this._db, {
    // `this._sector` as a named parameter: callers write it without the
    // underscore, `sector:`.
    required this._sector,
    required this._number,
    required this._centre,
  });

  final FirebaseFirestore _db;
  final SectorId _sector;
  final SectorNumber _number;
  final RescueCentre _centre;

  @override
  Future<void> hold(BanStreetId street, StreetPart part) =>
      FirestoreLayout.streetPart(_db, street).set(
        heldPartWrite(_sector, number: _number, centre: _centre, part: part),
        SetOptions(merge: true),
      );

  @override
  Future<void> release(BanStreetId street) =>
      releaseStreetPart(_db, _sector, street);

  /// Names this secteur as the one [reader]'s phone has open, in
  /// `openSectors/{uid}`: the security rules cannot search every secteur
  /// for the caller's member document, so they read the one named there
  /// before letting [reader] read the index (#147, PLAN §8.2). Sent once
  /// the secteur is opened, without waiting: queued offline like any
  /// write, and long received by the time « Partie de la rue » or
  /// « Ajouter des rues » reads the index. Not for an admin who only
  /// visits: an admin reads the index anyway, and the rules refuse to
  /// name a secteur one is not active in.
  void declareReader(MemberId reader) => sendInBackground(
    'open secteur ${_sector.value}',
    FirestoreLayout.openSector(_db, reader).set(openSectorDocument(_sector)),
  );

  @override
  Future<List<SectorPart>> othersOf(BanStreetId street) async {
    try {
      final snapshot = await FirestoreLayout.streetPart(_db, street).get();
      return otherPartsFrom(snapshot.data(), except: _sector);
    } on FirebaseException {
      return const [];
    }
  }
}

/// Removes the entry of [sector] for the BAN street [street]: when the
/// secteur no longer holds the street, and for each of its streets when
/// the secteur is deleted (by an admin, who may not be in it). The
/// document stays, with the other secteurs' entries. The `Future` ends
/// and fails as [FirestoreStreetPartIndex.hold]'s.
Future<void> releaseStreetPart(
  FirebaseFirestore db,
  SectorId sector,
  BanStreetId street,
) => FirestoreLayout.streetPart(
  db,
  street,
).set(releasedPartWrite(sector, FieldValue.delete()), SetOptions(merge: true));

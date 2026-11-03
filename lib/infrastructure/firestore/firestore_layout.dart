import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';

/// Where each document lives (PLAN §6.2), in one place for the Firestore
/// adapters.
abstract final class FirestoreLayout {
  static const sectors = 'sectors';
  static const members = 'members';
  static const campaigns = 'campaigns';
  static const streets = 'streets';
  static const rounds = 'rounds';
  static const joinCodes = 'joinCodes';
  static const sectorKeys = 'sectorKeys';
  static const rescueCentres = 'rescueCentres';
  static const admins = 'admins';

  /// `admins/{member}`: there when [member] is an admin (PLAN §5.12).
  static DocumentReference<Map<String, dynamic>> admin(
    FirebaseFirestore db,
    MemberId member,
  ) => db.collection(admins).doc(member.value);

  /// `sectors/{sector}`.
  static DocumentReference<Map<String, dynamic>> sector(
    FirebaseFirestore db,
    SectorId sector,
  ) => db.collection(sectors).doc(sector.value);

  /// `sectors/{sector}/members`.
  static CollectionReference<Map<String, dynamic>> membersOf(
    FirebaseFirestore db,
    SectorId sector,
  ) => FirestoreLayout.sector(db, sector).collection(members);

  /// `sectors/{sector}/campaigns/{year}/streets`.
  static CollectionReference<Map<String, dynamic>> streetsOf(
    FirebaseFirestore db,
    SectorId sector,
    CampaignYear campaign,
  ) => campaignOf(db, sector, campaign).collection(streets);

  /// `sectors/{sector}/campaigns/{year}/rounds`: the validated tournées
  /// (#63).
  static CollectionReference<Map<String, dynamic>> roundsOf(
    FirebaseFirestore db,
    SectorId sector,
    CampaignYear campaign,
  ) => campaignOf(db, sector, campaign).collection(rounds);

  /// `sectors/{sector}/campaigns/{year}`.
  static DocumentReference<Map<String, dynamic>> campaignOf(
    FirebaseFirestore db,
    SectorId sector,
    CampaignYear campaign,
  ) => FirestoreLayout.sector(
    db,
    sector,
  ).collection(campaigns).doc('${campaign.value}');
}

/// Whether [error] means the server could not be reached: offline, or no
/// answer in time.
bool isNoNetwork(FirebaseException error) =>
    error.code == 'unavailable' || error.code == 'deadline-exceeded';

/// Whether [error] means the security rules refused a request. For what
/// only an admin may do (create a tournée, a new code, delete, join
/// without a code, list every tournée), it means the phone is no longer an
/// admin's: its `admins/{uid}` was removed while the phone still showed
/// the command (PLAN §5.12).
bool isRefused(FirebaseException error) => error.code == 'permission-denied';

/// Whether [error] means this member may no longer read what a listener
/// follows: removed from the tournée, left it, or refused. Listeners take
/// it as « nothing there » rather than as a failure.
bool isNoLongerReadable(Object error) =>
    error is FirebaseException && error.code == 'permission-denied';

/// Sends [write] without waiting for the server to receive it.
///
/// Firestore applies a write to the phone's copy at once and completes its
/// `Future` only when the server has it, which offline can take hours: the
/// screens must not wait for that (PLAN §7). The write stays queued on the
/// phone, across restarts, until it is sent. If the server refuses it (the
/// security rules), Firestore takes it back out of the phone's copy and
/// the listeners show the street as it was; the reason is only logged
/// (`adb logcat`), since the user cannot act on it.
void sendInBackground(String what, Future<void> write) {
  unawaited(
    write.then<void>(
      (_) {},
      onError: (Object error) =>
          debugPrint('Firestore write failed ($what): $error'),
    ),
  );
}

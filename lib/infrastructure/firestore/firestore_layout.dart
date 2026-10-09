import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';

/// Where each document lives (PLAN §6.2), in one place for the three
/// Firestore adapters.
abstract final class FirestoreLayout {
  static const tournees = 'tournees';
  static const members = 'members';
  static const campaigns = 'campaigns';
  static const streets = 'streets';
  static const joinCodes = 'joinCodes';
  static const tourneeKeys = 'tourneeKeys';
  static const rescueCentres = 'rescueCentres';

  /// `tournees/{tournee}`.
  static DocumentReference<Map<String, dynamic>> tournee(
    FirebaseFirestore db,
    TourneeId tournee,
  ) => db.collection(tournees).doc(tournee.value);

  /// `tournees/{tournee}/members`.
  static CollectionReference<Map<String, dynamic>> membersOf(
    FirebaseFirestore db,
    TourneeId tournee,
  ) => FirestoreLayout.tournee(db, tournee).collection(members);

  /// `tournees/{tournee}/campaigns/{year}/streets`.
  static CollectionReference<Map<String, dynamic>> streetsOf(
    FirebaseFirestore db,
    TourneeId tournee,
    CampaignYear campaign,
  ) => FirestoreLayout.tournee(
    db,
    tournee,
  ).collection(campaigns).doc('${campaign.value}').collection(streets);
}

/// Whether [error] means the server could not be reached: offline, or no
/// answer in time.
bool isNoNetwork(FirebaseException error) =>
    error.code == 'unavailable' || error.code == 'deadline-exceeded';

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

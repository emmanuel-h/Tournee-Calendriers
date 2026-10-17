// Translation between a Tournee and its Firestore documents (PLAN §6.2).
// Pure functions, tested alone.
//
//   tournees/{id}            { number, centreKey, centreName, joinCode,
//                              createdBy: uid, createdAt: time,
//                              currentCampaign: 2026,
//                              communes: [{ code: "69264",
//                                name: "Villefranche-sur-Saône",
//                                lat: 45.98 | null, lon: 4.72 | null }] }
//     members/{uid}          { displayName, status: "pending" | "active",
//                              requestedAt: time, acceptedBy: uid | null,
//                              acceptedAt: time | null,
//                              joinCode (only on a request, see below) }
//     campaigns/{year}       { startedAt: time, previousYear: null }
//   joinCodes/{code}         { tourneeId, number, centreName, campaign }
//   tourneeKeys/{key}_{n}    { tourneeId }      ← "villefranche_49"
//   rescueCentres/{key}      { name }           ← "villefranche"
//
// A newcomer's request carries the code it was made with, so the security
// rules can check it is still the tournée's code (PLAN §8.2): the newcomer
// cannot read the tournée to prove it otherwise.
//
// Reading goes back through the domain's checks (Tournee.create,
// MemberName.create…); anything they refuse is a FormatException. The
// communes are the exception: a tournée written before them has none, and
// one entry the domain refuses (or a second entry of the same code, which
// the security rules cannot rule out) is left out, so the team still
// reads its tournée.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_commune.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_loss.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/stored_values.dart';

/// The document `tournees/{id}` of [tournee]; its members are documents of
/// their own.
Map<String, Object?> tourneeToDocument(Tournee tournee) => {
  'number': tournee.number.value,
  'centreKey': tournee.centre.key.value,
  'centreName': tournee.centre.name,
  'joinCode': tournee.joinCode.value,
  'createdBy': tournee.createdBy.value,
  'createdAt': Timestamp.fromDate(tournee.createdAt),
  'currentCampaign': tournee.currentCampaign.value,
  'communes': [for (final commune in tournee.communes) communeEntry(commune)],
};

/// The entry of [commune] in the tournée's `communes` list. Adding or
/// removing one names the whole entry (`arrayUnion` / `arrayRemove`
/// compare entries by value), so it is always written the same way.
Map<String, Object?> communeEntry(TourneeCommune commune) => {
  'code': commune.inseeCode.value,
  'name': commune.name,
  'lat': commune.centre?.latitude,
  'lon': commune.centre?.longitude,
};

/// The document `members/{uid}` of [member].
Map<String, Object?> memberToDocument(Member member) => {
  'displayName': member.name.text,
  'status': _statusName(member),
  'requestedAt': Timestamp.fromDate(member.requestedAt),
  ...acceptanceFields(member),
};

/// The document of a newcomer's [request], made with [code].
Map<String, Object?> joinRequestDocument(Member request, JoinCode code) => {
  ...memberToDocument(request),
  'joinCode': code.value,
};

/// The fields an acceptance changes on [member]'s document: its status,
/// who accepted and when.
Map<String, Object?> acceptanceFields(Member member) => {
  'status': _statusName(member),
  'acceptedBy': member.acceptance?.by.value,
  'acceptedAt': switch (member.acceptance) {
    null => null,
    final ChangeStamp acceptance => Timestamp.fromDate(acceptance.at),
  },
};

/// The field a rename changes on [member]'s document: only its name, so a
/// teammate's acceptance written at the same time is not overwritten.
Map<String, Object?> displayNameFields(Member member) => {
  'displayName': member.name.text,
};

/// The tournée stored in `tournees/[id]` as [data], with its [members]
/// (each document's data by uid).
///
/// Throws a [FormatException] when a document is not what this code writes
/// or holds a value the domain refuses.
Tournee tourneeFromDocuments(
  String id,
  Map<String, Object?> data,
  Map<String, Map<String, Object?>> members,
) {
  if (data case {
    'number': final int number,
    'centreName': final String centreName,
    'joinCode': final String joinCode,
    'createdBy': final String createdBy,
    'createdAt': final Object? createdAt,
    'currentCampaign': final int currentCampaign,
  }) {
    // The stored `centreKey` is not read back: the key is always made from
    // the name, by the domain's own rule.
    return valid(
      Tournee.create(
        id: identifier(id, TourneeId.new),
        number: valid(TourneeNumber.create(number), 'tournée number'),
        centre: valid(RescueCentre.create(centreName), 'centre de secours'),
        joinCode: valid(JoinCode.parse(joinCode), 'join code'),
        createdBy: identifier(createdBy, MemberId.new),
        createdAt: timeFrom(createdAt),
        currentCampaign: valid(CampaignYear.create(currentCampaign), 'year'),
        members: [
          for (final MapEntry(:key, :value) in members.entries)
            memberFromDocument(key, value),
        ],
        communes: communesFrom(data['communes']),
      ),
      'tournée',
    );
  }
  throw const FormatException('Not a tournée document');
}

/// The communes of a tournée's stored `communes` list, in their order:
/// none when there is no list (a tournée written before them). An entry
/// that cannot be read, or whose code an earlier entry has, is left out;
/// beyond [Tournee.maxCommunes] the rest is ignored.
List<TourneeCommune> communesFrom(Object? json) {
  final communes = <InseeCode, TourneeCommune>{};
  if (json is List<Object?>) {
    for (final entry in json) {
      final commune = _communeFrom(entry);
      if (commune == null || communes.length == Tournee.maxCommunes) continue;
      // `putIfAbsent`: the first entry of a code wins.
      communes.putIfAbsent(commune.inseeCode, () => commune);
    }
  }
  return communes.values.toList();
}

/// The commune of one stored entry; null when it cannot be read: not a
/// commune, a centre out of range, or half a centre.
TourneeCommune? _communeFrom(Object? entry) {
  if (entry case {
    'code': final String code,
    'name': final String name,
    'lat': final num? latitude,
    'lon': final num? longitude,
  }) {
    if (Commune.create(inseeCode: code, name: name) case Ok(
      value: final commune,
    )) {
      if (latitude == null || longitude == null) {
        // Both null: no centre. Only one: half a centre, not to be trusted.
        return latitude == longitude ? TourneeCommune(commune: commune) : null;
      }
      if (GeoPoint.create(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          )
          case Ok(value: final centre)) {
        return TourneeCommune(commune: commune, centre: centre);
      }
    }
  }
  return null;
}

/// The member stored in `members/[uid]` as [data].
Member memberFromDocument(String uid, Map<String, Object?> data) {
  if (data case {
    'displayName': final String name,
    'status': final String status,
    'requestedAt': final Object? requestedAt,
    'acceptedBy': final String? acceptedBy,
    'acceptedAt': final Object? acceptedAt,
  }) {
    final member = Member(
      id: identifier(uid, MemberId.new),
      name: valid(MemberName.create(name), 'member name'),
      requestedAt: timeFrom(requestedAt),
      acceptance: stampOrNull(acceptedBy, acceptedAt),
    );
    // The status is derived from the acceptance in the domain; a stored
    // one that disagrees is damaged data.
    if (_statusName(member) != status) {
      throw FormatException('Status not matching the acceptance', status);
    }
    return member;
  }
  throw FormatException('Not a member document', uid);
}

/// What one snapshot of a newcomer's member document `members/[uid]` tells
/// of their request (« Demande envoyée », PLAN §5.2): its status, null once
/// the request is gone (refused, cancelled), or nothing at all.
///
/// [data] is null when the document does not exist in the snapshot. When
/// that snapshot comes only from the phone's copy ([fromCache]), the
/// document may simply never have been read on this phone (an offline
/// start after the copy was cleared): that is no answer, so the list is
/// empty, and a pending request is never dropped without the server
/// saying so. A list rather than a nullable status, since null is itself
/// an answer.
List<MemberStatus?> requestStatusesIn(
  String uid,
  Map<String, Object?>? data, {
  required bool fromCache,
}) => switch (data) {
  final data? => [memberFromDocument(uid, data).status],
  null when fromCache => const [],
  null => const [null],
};

/// The name one snapshot of the member's own document `members/[uid]`
/// holds on the server, once they are active in the tournée, cleaned as
/// `MemberName` cleans it; nothing otherwise. A list rather than a
/// nullable name, as [requestStatusesIn].
///
/// Only the server's word counts: the phone's copy ([fromCache]) may be
/// stale, and a snapshot carrying this phone's own write not yet sent
/// ([hasPendingWrites]) shows what the phone asked, not what the team
/// sees. A pending request has no name to catch up (PLAN §8.2), nor has
/// a document that is gone ([data] null).
List<MemberName> confirmedNamesIn(
  String uid,
  Map<String, Object?>? data, {
  required bool fromCache,
  required bool hasPendingWrites,
}) {
  if (data == null || fromCache || hasPendingWrites) return const [];
  final member = memberFromDocument(uid, data);
  return member.isActive ? [member.name] : const [];
}

/// Whether a snapshot of a document the phone follows says it is gone:
/// the member's own document (no longer in the tournée), the tournée an
/// admin visits (deleted), the phone's `admins/{uid}` (no longer an
/// admin). Only the server's word, without the document, counts. The
/// phone's copy without it ([fromCache]: offline, or never read) tells
/// nothing, nor does a deletion made on this phone and not yet sent
/// ([hasPendingWrites]: leaving, deleting), which the use cases settle
/// themselves.
bool isGoneOnServer({
  required bool exists,
  required bool fromCache,
  required bool hasPendingWrites,
}) => !exists && !fromCache && !hasPendingWrites;

/// How the member lost [tournee] once their member document is gone, from
/// the reservation of its number (`tourneeKeys/{key}` read from the
/// server, null when there is none): it still names the tournée while the
/// tournée exists, so the member was removed; it goes with the tournée
/// (in the same batch, PLAN §8.2), so without it the tournée was deleted.
TourneeLoss lossFromReservation(
  TourneeId tournee,
  Map<String, Object?>? reservation,
) => switch (reservation) {
  final data? when tourneeIdFromKeyDocument(data) == tournee =>
    TourneeLoss.removed,
  _ => TourneeLoss.deleted,
};

/// What « Toutes les tournées » shows of [tournee] to the admin [caller]
/// (PLAN §5.12): its members and requests counted, and whether [caller] is
/// in its team.
TourneeOverview overviewOf(Tournee tournee, MemberId caller) => TourneeOverview(
  id: tournee.id,
  number: tournee.number,
  centre: tournee.centre,
  campaign: tournee.currentCampaign,
  activeMembers: tournee.activeMembers.length,
  pendingRequests: tournee.pendingMembers.length,
  callerIsActive: tournee.memberOf(caller)?.isActive ?? false,
);

/// The document `joinCodes/{code}` of [tournee]: only what the join screen
/// shows (PLAN §8.2).
Map<String, Object?> joinCodeDocument(Tournee tournee) => {
  'tourneeId': tournee.id.value,
  'number': tournee.number.value,
  'centreName': tournee.centre.name,
  'campaign': tournee.currentCampaign.value,
};

/// The preview stored in `joinCodes/[code]` as [data].
JoinPreview joinPreviewFromDocument(JoinCode code, Map<String, Object?> data) {
  if (data case {
    'tourneeId': final String tourneeId,
    'number': final int number,
    'centreName': final String centreName,
    'campaign': final int campaign,
  }) {
    return JoinPreview(
      code: code,
      tourneeId: identifier(tourneeId, TourneeId.new),
      number: valid(TourneeNumber.create(number), 'tournée number'),
      centre: valid(RescueCentre.create(centreName), 'centre de secours'),
      campaign: valid(CampaignYear.create(campaign), 'year'),
    );
  }
  throw FormatException('Not a join code document', code.value);
}

/// The id of the document `tourneeKeys/{id}` that reserves [number] in
/// [centre]: `villefranche_49`. Its existence is what makes number + centre
/// unique across the app (PLAN §6.2).
String tourneeKeyId(RescueCentre centre, TourneeNumber number) =>
    '${centre.key.value}_${number.value}';

/// The document `tourneeKeys/{id}` of [tournee].
Map<String, Object?> tourneeKeyDocument(Tournee tournee) => {
  'tourneeId': tournee.id.value,
};

/// The tournée holding the reservation stored as [data].
TourneeId tourneeIdFromKeyDocument(Map<String, Object?> data) {
  if (data case {'tourneeId': final String id}) {
    return identifier(id, TourneeId.new);
  }
  throw const FormatException('Not a tournée key document');
}

/// The document `campaigns/{year}` of the campaign [tournee] starts with.
Map<String, Object?> firstCampaignDocument(Tournee tournee) => {
  'startedAt': Timestamp.fromDate(tournee.createdAt),
  'previousYear': null,
};

/// The document `rescueCentres/{key}` of [centre].
Map<String, Object?> rescueCentreDocument(RescueCentre centre) => {
  'name': centre.name,
};

/// The centre stored as [data].
RescueCentre rescueCentreFromDocument(Map<String, Object?> data) {
  if (data case {'name': final String name}) {
    return valid(RescueCentre.create(name), 'centre de secours');
  }
  throw const FormatException('Not a centre de secours document');
}

/// A member is pending or active; only the phone's own summary of a
/// tournée is ever « visiting » (PLAN §5.12), never a member document.
String _statusName(Member member) => member.isActive ? 'active' : 'pending';

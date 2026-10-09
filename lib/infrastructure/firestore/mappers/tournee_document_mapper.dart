// Translation between a Tournee and its Firestore documents (PLAN §6.2).
// Pure functions, tested alone.
//
//   tournees/{id}            { number, centreKey, centreName, joinCode,
//                              createdBy: uid, createdAt: time,
//                              currentCampaign: 2026 }
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
// MemberName.create…); anything they refuse is a FormatException.
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:tournee_calendriers/application/ports/tournee_directory.dart';
import 'package:tournee_calendriers/domain/shared/change_stamp.dart';
import 'package:tournee_calendriers/domain/shared/member_id.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/join_code.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
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
};

/// The document `members/{uid}` of [member].
Map<String, Object?> memberToDocument(Member member) => {
  'displayName': member.name.text,
  'status': _statusName(member.status),
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
  'status': _statusName(member.status),
  'acceptedBy': member.acceptance?.by.value,
  'acceptedAt': switch (member.acceptance) {
    null => null,
    final ChangeStamp acceptance => Timestamp.fromDate(acceptance.at),
  },
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
      ),
      'tournée',
    );
  }
  throw const FormatException('Not a tournée document');
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
    if (_statusName(member.status) != status) {
      throw FormatException('Status not matching the acceptance', status);
    }
    return member;
  }
  throw FormatException('Not a member document', uid);
}

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

String _statusName(MemberStatus status) => switch (status) {
  MemberStatus.pending => 'pending',
  MemberStatus.active => 'active',
};

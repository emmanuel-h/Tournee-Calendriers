// Translation between « Mes tournées » (PLAN §6.3) and the JSON the phone
// keeps for them. Pure functions: no file here, so they are tested alone.
//
// The schema, version 1:
//
//   { version: 1,
//     open: tourneeId | null,                    ← the tournée the app shows
//     tournees: [ { id, number: 49, centre: "CS Villefranche",
//                   campaign: 2026, status: "active" | "pending" }, … ] }
//
// Statuses under fixed names, so renaming the Dart enum never changes what
// is on the phone. Every value goes through the domain's checks.
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/member.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';

/// The schema version this code writes and reads.
const storedMyTourneesVersion = 1;

const _active = 'active';
const _pending = 'pending';

/// The stored form of [mine].
Map<String, Object?> myTourneesToJson(MyTournees mine) => {
  'version': storedMyTourneesVersion,
  'open': mine.currentId?.value,
  'tournees': [
    for (final tournee in mine.tournees)
      {
        'id': tournee.id.value,
        'number': tournee.number.value,
        'centre': tournee.centre.name,
        'campaign': tournee.campaign.value,
        'status': switch (tournee.status) {
          MemberStatus.active => _active,
          MemberStatus.pending => _pending,
        },
      },
  ],
};

/// « Mes tournées » read from [json] as `jsonDecode` gives it. Throws a
/// [FormatException] when it is not a version 1 file, or when a value
/// breaks the domain's rules (the open tournée must be an active one of the
/// list).
MyTournees myTourneesFromJson(Object? json) {
  // A map pattern: matches only a map with these entries of these types.
  // `open` must be there, null or a text.
  if (json case {
    'version': storedMyTourneesVersion,
    'open': final String? open,
    'tournees': final List<Object?> tournees,
  }) {
    var mine = MyTournees.none;
    for (final tournee in tournees) {
      mine = mine.remember(_tourneeFromJson(tournee));
    }
    if (open == null) return mine;
    return switch (mine.open(TourneeId(open))) {
      Ok(:final value) => value,
      Err(:final failure) => throw FormatException(
        'Cannot open $open: ${failure.name}',
      ),
    };
  }
  throw FormatException('Not « Mes tournées »: $json');
}

TourneeSummary _tourneeFromJson(Object? json) {
  if (json
      case {
        'id': final String id,
        'number': final int number,
        'centre': final String centre,
        'campaign': final int campaign,
        'status': final String status,
      }
      when id.trim().isNotEmpty) {
    return TourneeSummary(
      id: TourneeId(id),
      number: _valid(TourneeNumber.create(number), json),
      centre: _valid(RescueCentre.create(centre), json),
      campaign: _valid(CampaignYear.create(campaign), json),
      status: switch (status) {
        _active => MemberStatus.active,
        _pending => MemberStatus.pending,
        _ => throw FormatException('Not a status: $status'),
      },
    );
  }
  throw FormatException('Not a tournée: $json');
}

/// The value of [result], or a [FormatException] naming [json].
T _valid<T, F>(Result<T, F> result, Object json) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw FormatException('$failure in $json'),
};

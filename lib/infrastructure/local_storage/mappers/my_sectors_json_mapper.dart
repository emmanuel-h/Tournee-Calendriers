// Translation between « Mes secteurs » (PLAN §6.3) and the JSON the phone
// keeps for them. Pure functions: no file here, so they are tested alone.
//
// The schema, version 1:
//
//   { version: 1,
//     open: sectorId | null,                    ← the tournée the app shows
//     tournees: [ { id, number: 49, centre: "CS Villefranche",
//                   campaign: 2026,
//                   status: "active" | "pending" | "visiting" }, … ] }
//
// "visiting" (PLAN §5.12, #75) is a tournée an admin opened without being
// in its team. An app older than #75 cannot read a file holding one, and
// starts with none: only an admin's phone ever writes it.
//
// The key `tournees` (and the file name, `my_tournees.json`) date from
// before the code said « sector » (#116). They stay as they are, so a phone
// updated from an older version still finds its sectors and the open one:
// a name on the phone is not renamed with the code.
//
// Statuses under fixed names, so renaming the Dart enum never changes what
// is on the phone. Every value goes through the domain's checks.
import 'package:tournee_calendriers/domain/sector/campaign_year.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/rescue_centre.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/domain/sector/sector_number.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';

/// The schema version this code writes and reads.
const storedMySectorsVersion = 1;

const _active = 'active';
const _pending = 'pending';
const _visiting = 'visiting';

/// The stored form of [mine].
Map<String, Object?> mySectorsToJson(MySectors mine) => {
  'version': storedMySectorsVersion,
  'open': mine.currentId?.value,
  'tournees': [
    for (final sector in mine.sectors)
      {
        'id': sector.id.value,
        'number': sector.number.value,
        'centre': sector.centre.name,
        'campaign': sector.campaign.value,
        'status': switch (sector.status) {
          MemberStatus.active => _active,
          MemberStatus.pending => _pending,
          MemberStatus.visiting => _visiting,
        },
      },
  ],
};

/// « Mes secteurs » read from [json] as `jsonDecode` gives it. Throws a
/// [FormatException] when it is not a version 1 file, or when a value
/// breaks the domain's rules (the open tournée must be an active one of the
/// list).
MySectors mySectorsFromJson(Object? json) {
  // A map pattern: matches only a map with these entries of these types.
  // `open` must be there, null or a text.
  if (json case {
    'version': storedMySectorsVersion,
    'open': final String? open,
    'tournees': final List<Object?> sectors,
  }) {
    var mine = MySectors.none;
    for (final sector in sectors) {
      mine = mine.remember(_sectorFromJson(sector));
    }
    if (open == null) return mine;
    return switch (mine.open(SectorId(open))) {
      Ok(:final value) => value,
      Err(:final failure) => throw FormatException(
        'Cannot open $open: ${failure.name}',
      ),
    };
  }
  throw FormatException('Not « Mes secteurs »: $json');
}

SectorSummary _sectorFromJson(Object? json) {
  if (json
      case {
        'id': final String id,
        'number': final int number,
        'centre': final String centre,
        'campaign': final int campaign,
        'status': final String status,
      }
      when id.trim().isNotEmpty) {
    return SectorSummary(
      id: SectorId(id),
      number: _valid(SectorNumber.create(number), json),
      centre: _valid(RescueCentre.create(centre), json),
      campaign: _valid(CampaignYear.create(campaign), json),
      status: switch (status) {
        _active => MemberStatus.active,
        _pending => MemberStatus.pending,
        _visiting => MemberStatus.visiting,
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

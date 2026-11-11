import 'package:tournee_calendriers/application/ports/street_part_index.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// What the other secteurs hold of a BAN street (PLAN §5.15 « Other
/// secteurs »): the hatching and the warning of « Partie de la rue », and
/// the line « Secteur 12 : impairs 19–41 » under a street to add.
///
/// Only a hint, read in the background: none when it cannot be read, and
/// nothing ever waits for it.
final class ReadOtherSectorParts {
  const ReadOtherSectorParts(this._index);

  final StreetPartIndex _index;

  /// The other secteurs' parts of [street], by secteur number (then by
  /// centre, two centres may each have a secteur 12).
  Future<List<SectorPart>> call(BanStreetId street) async {
    final others = [...await _index.othersOf(street)];
    return others..sort((a, b) {
      final bySector = a.sector.value.compareTo(b.sector.value);
      return bySector != 0 ? bySector : a.centre.name.compareTo(b.centre.name);
    });
  }
}

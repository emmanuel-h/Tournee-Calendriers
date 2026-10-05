import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// Where a street imported before stands on the phone.
enum ImportedStreetState {
  /// In « Mes rues »: importing it again leaves it as it is.
  active,

  /// In the Corbeille: importing it again brings it back with its marks.
  inCorbeille,
}

/// Which streets of a commune are already on the phone, so the import
/// screen shows them « déjà importée » (ticked and greyed) or « dans la
/// Corbeille » (free to tick). Works offline.
final class FindImportedStreets {
  const FindImportedStreets(this._streets);

  final StreetRepository _streets;

  /// The BAN ids among [ids] that a street on the phone was imported from,
  /// each with where that street stands. The ids of streets never imported
  /// are left out.
  Future<Map<BanStreetId, ImportedStreetState>> call(
    Iterable<BanStreetId> ids,
  ) async => {
    for (final id in ids)
      if (await _streets.findByBanId(id) case final street?)
        id: street.isDeleted
            ? ImportedStreetState.inCorbeille
            : ImportedStreetState.active,
  };
}

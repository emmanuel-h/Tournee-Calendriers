import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// Which streets of a commune are already on the phone, so the import
/// screen shows them ticked, greyed and « déjà importée ». Works offline.
///
/// A street in the Corbeille counts as imported, as for
/// `ImportReferenceArea`, which would leave it as it is.
final class FindImportedStreets {
  const FindImportedStreets(this._streets);

  final StreetRepository _streets;

  /// The BAN ids among [ids] that a street on the phone was imported from.
  Future<Set<BanStreetId>> call(Iterable<BanStreetId> ids) async => {
    for (final id in ids)
      if (await _streets.findByBanId(id) != null) id,
  };
}

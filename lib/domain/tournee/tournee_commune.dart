import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';

/// A commune a tournée covers (PLAN §5.2, §6.1): « Villefranche-sur-Saône »,
/// with the point the map of « Ajouter des rues » centres on.
///
/// The [centre] is captured when the commune is picked (geo.api.gouv.fr
/// gives it with the search), and stored with the tournée, so the map is
/// centred offline too. Null when the service gave none: the map then
/// starts on the tournée's streets.
final class TourneeCommune {
  const TourneeCommune({required this.commune, this.centre});

  final Commune commune;

  /// The commune's centre (its town hall, roughly), or null.
  final GeoPoint? centre;

  /// Which commune: two entries of a tournée never share it.
  InseeCode get inseeCode => commune.inseeCode;

  /// The official name, as the screens show it.
  String get name => commune.name;

  @override
  bool operator ==(Object other) =>
      other is TourneeCommune &&
      other.commune == commune &&
      other.centre == centre;

  @override
  int get hashCode => Object.hash(commune, centre);

  @override
  String toString() => 'TourneeCommune(${inseeCode.value}, $name, $centre)';
}

import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

/// The national address base (BAN), as the app needs it: the streets of a
/// commune, the numbers of a street with where each entrance is, the street
/// under a tap on the map and the streets whose name looks like a search.
///
/// An outbound port: the application owns this interface, an adapter in
/// `infrastructure/ban/` implements it over HTTP (the BAN itself and its
/// geocoder on the Géoplateforme, PLAN §9), and tests use a fake. The rest of
/// the app never sees a URL or JSON.
///
/// Every call needs the network. A failure the user can act on (no network,
/// unknown code, the service is down) comes back as an [Err] holding an
/// [AddressDirectoryFailure], never as an exception.
abstract interface class AddressDirectory {
  /// The streets of the commune [inseeCode] (`69264`), as the import
  /// screen lists them.
  ///
  /// [AddressDirectoryFailure.notFound] when the BAN knows no such commune.
  Future<Result<CommuneStreets, AddressDirectoryFailure>> streetsOf(
    InseeCode inseeCode,
  );

  /// The numbers of the street [street], each with its position when the
  /// BAN has one.
  ///
  /// [AddressDirectoryFailure.notFound] when the BAN knows no such street.
  Future<Result<StreetNumbers, AddressDirectoryFailure>> numbersOf(
    BanStreetId street,
  );

  /// The BAN street nearest to [point], where the user tapped a road on the
  /// map (« Ajouter des rues », PLAN §5.4).
  ///
  /// The geocoder measures the distance to one point of each street, not to
  /// the road itself, and answers the nearest whatever the distance: the
  /// street may be in the next commune, and a road the BAN does not know
  /// (a private road) gives the nearest one it knows. The screen shows the
  /// name found so the user can tell.
  ///
  /// [AddressDirectoryFailure.notFound] when no street is near at all.
  Future<Result<StreetMatch, AddressDirectoryFailure>> streetAt(GeoPoint point);

  /// The streets of [commune] whose name looks like [text] (« rue pierre »),
  /// best first, at most ten; none when nothing does.
  ///
  /// Spaces around [text] and the signs before its first letter or digit
  /// are ignored. The service needs 3 to 200 characters: a shorter or
  /// longer text finds nothing, without asking it (so typing the first
  /// letters costs no request).
  Future<Result<List<StreetMatch>, AddressDirectoryFailure>> searchStreets(
    String text, {
    required InseeCode commune,
  });
}

/// Why the [AddressDirectory] could not answer. Each case is phrased in
/// French by the screen that asked.
enum AddressDirectoryFailure {
  /// The phone could not reach the service, or it did not answer in time.
  /// Trying again with a better signal may work.
  noNetwork,

  /// The service has no commune or street with that code, or no street near
  /// the point asked.
  notFound,

  /// The service answered with an error or with something unreadable.
  /// Trying again later may work.
  serviceError,
}

/// A street of a commune as the [AddressDirectory] lists it, before it is
/// imported.
final class DirectoryStreet {
  const DirectoryStreet({
    required this.id,
    required this.name,
    required this.numberCount,
  });

  final BanStreetId id;
  final StreetName name;

  /// How many numbers the BAN gives the street (`403 n°` on the import
  /// screen). A hint only: the import may keep fewer, see [StreetNumbers].
  final int numberCount;

  @override
  bool operator ==(Object other) =>
      other is DirectoryStreet &&
      other.id == id &&
      other.name == name &&
      other.numberCount == numberCount;

  @override
  int get hashCode => Object.hash(id, name, numberCount);

  @override
  String toString() =>
      'DirectoryStreet(${id.value}, ${name.text}, $numberCount)';
}

/// The streets of one commune, in the order the BAN gives them.
final class CommuneStreets {
  /// [streets] is copied, so changing the list given here afterwards does
  /// not change this value.
  CommuneStreets({
    required this.commune,
    required List<DirectoryStreet> streets,
    required this.skippedStreets,
  }) : streets = List.unmodifiable(streets);

  final Commune commune;

  /// Read-only: adding to it throws an [UnsupportedError].
  final List<DirectoryStreet> streets;

  /// How many entries of the BAN's list were left out because they could
  /// not be read (no id, or a name that is not a valid [StreetName]).
  final int skippedStreets;
}

/// A house number of a street as the [AddressDirectory] gives it.
final class DirectoryNumber {
  const DirectoryNumber({required this.number, this.position});

  final HouseNumber number;

  /// Where the entrance is; null when the BAN gives no usable position. The
  /// number is kept anyway: the house is still there to be visited, only its
  /// dot on the map is missing.
  final GeoPoint? position;

  @override
  bool operator ==(Object other) =>
      other is DirectoryNumber &&
      other.number == number &&
      other.position == position;

  @override
  int get hashCode => Object.hash(number, position);

  @override
  String toString() => 'DirectoryNumber(${number.label}, $position)';
}

/// The numbers of one street, each once, in the order the BAN gives them.
///
/// Real data must never break an import, so numbers the app cannot take are
/// left out and counted rather than failing the whole street.
final class StreetNumbers {
  /// [numbers] is copied, so changing the list given here afterwards does
  /// not change this value.
  StreetNumbers({
    required this.id,
    required this.name,
    required this.commune,
    required List<DirectoryNumber> numbers,
    required this.invalidNumbers,
    required this.duplicateNumbers,
  }) : numbers = List.unmodifiable(numbers);

  final BanStreetId id;
  final StreetName name;
  final Commune commune;

  /// Read-only: adding to it throws an [UnsupportedError]. May be empty.
  final List<DirectoryNumber> numbers;

  /// How many entries were left out because they are not a valid
  /// [HouseNumber] (a number above 99999, a suffix such as `12-1`).
  final int invalidNumbers;

  /// How many entries were left out because an earlier entry of the street
  /// has the same number (the BAN sometimes lists a number twice, with two
  /// positions): the first one is kept.
  final int duplicateNumbers;
}

/// A street the [AddressDirectory] found at a point or by its name, before
/// it is added: enough to name it on the street card and to centre the map
/// on it. Its numbers come from [AddressDirectory.numbersOf].
final class StreetMatch {
  const StreetMatch({
    required this.id,
    required this.name,
    required this.commune,
    required this.position,
  });

  final BanStreetId id;
  final StreetName name;
  final Commune commune;

  /// The one point the geocoder gives the street, on it or next to it:
  /// where the map goes to show it.
  final GeoPoint position;

  @override
  bool operator ==(Object other) =>
      other is StreetMatch &&
      other.id == id &&
      other.name == name &&
      other.commune == commune &&
      other.position == position;

  @override
  int get hashCode => Object.hash(id, name, commune, position);

  @override
  String toString() =>
      'StreetMatch(${id.value}, ${name.text}, ${commune.name}, $position)';
}

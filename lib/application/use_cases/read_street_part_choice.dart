import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// Why [ReadStreetPartChoice] could not open « Partie de la rue ».
/// `sealed`: the screen phrases each case in French.
sealed class PartChoiceRefusal {
  const PartChoiceRefusal();
}

/// No street has that id (a teammate's purge took it meanwhile).
final class PartChoiceOfUnknownStreet extends PartChoiceRefusal {
  const PartChoiceOfUnknownStreet();

  @override
  bool operator ==(Object other) => other is PartChoiceOfUnknownStreet;

  @override
  int get hashCode => (PartChoiceOfUnknownStreet).hashCode;

  @override
  String toString() => 'PartChoiceOfUnknownStreet';
}

/// The BAN could not give the street's numbers, for [reason]:
/// [AddressDirectoryFailure.noNetwork] is « Connexion nécessaire… »,
/// [AddressDirectoryFailure.serviceError] « Impossible de … pour
/// l'instant ».
final class PartChoiceUnreadable extends PartChoiceRefusal {
  const PartChoiceUnreadable(this.reason);

  final AddressDirectoryFailure reason;

  @override
  bool operator ==(Object other) =>
      other is PartChoiceUnreadable && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'PartChoiceUnreadable($reason)';
}

/// « Partie de la rue » in edit mode (PLAN §5.15): what the part of a
/// street already in the secteur is chosen among.
///
/// The street holds only the numbers of its part, so the others come from
/// the BAN: it reads the street's numbers again, with their positions
/// (network). The street's own numbers, shown or in the Corbeille, are
/// added (« + numéros » may have added some the BAN does not know), with
/// their own positions. A street typed by hand, or one the BAN no longer
/// knows, is chosen among its own numbers, without network.
final class ReadStreetPartChoice {
  const ReadStreetPartChoice(this._streets, this._directory);

  final StreetRepository _streets;
  final AddressDirectory _directory;

  Future<Result<StreetPartChoice, PartChoiceRefusal>> call(
    StreetId streetId,
  ) async {
    final street = await _streets.find(streetId);
    if (street == null) return const Err(PartChoiceOfUnknownStreet());
    var fromDirectory = const <DirectoryNumber>[];
    if (street.banId case final banId?) {
      switch (await _directory.numbersOf(banId)) {
        case Ok(:final value):
          fromDirectory = value.numbers;
        // The BAN no longer knows the street: its own numbers are all
        // there is.
        case Err(failure: AddressDirectoryFailure.notFound):
          break;
        case Err(:final failure):
          return Err(PartChoiceUnreadable(failure));
      }
    }
    // Where each number is: the street's own position first (the BAN's was
    // copied there when the street was added), the BAN's otherwise.
    final places = <HouseNumber, GeoPoint?>{
      for (final DirectoryNumber(:number, :position) in fromDirectory)
        number: position,
    };
    for (final House(:number, :position) in [
      ...street.houses,
      for (final removed in street.removedHouses) removed.house,
    ]) {
      places[number] = position ?? places[number];
    }
    return Ok(
      StreetPartChoice.start(
        numbers: [
          for (final MapEntry(key: number, value: position) in places.entries)
            PartNumber(number, position: position),
        ],
        road: street.shape,
        part: street.part,
      ),
    );
  }
}

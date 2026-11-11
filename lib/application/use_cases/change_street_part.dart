import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/ports/identity_provider.dart';
import 'package:tournee_calendriers/application/use_cases/command_failure.dart';
import 'package:tournee_calendriers/application/use_cases/street_command.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/same_items.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_change.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// Why [ChangeStreetPart] changed nothing. `sealed`: the screen phrases
/// each case in French.
sealed class PartChangeRefusal {
  const PartChangeRefusal();
}

/// No street has that id (a teammate's purge took it meanwhile).
final class PartOfUnknownStreet extends PartChangeRefusal {
  const PartOfUnknownStreet();

  @override
  bool operator ==(Object other) => other is PartOfUnknownStreet;

  @override
  int get hashCode => (PartOfUnknownStreet).hashCode;

  @override
  String toString() => 'PartOfUnknownStreet';
}

/// The part given is the street's already: « Valider » just closes.
final class SamePart extends PartChangeRefusal {
  const SamePart();

  @override
  bool operator ==(Object other) => other is SamePart;

  @override
  int get hashCode => (SamePart).hashCode;

  @override
  String toString() => 'SamePart';
}

/// The new part leaves out [numbers], which have marks: the screen asks
/// first (« 3 numéros ont des marques. Ils partent avec elles à la
/// Corbeille. »), then calls again with `marksConfirmed: true`.
final class MarkedNumbersLeaving extends PartChangeRefusal {
  MarkedNumbersLeaving(Iterable<HouseNumber> numbers)
    : numbers = List.unmodifiable(numbers);

  /// The numbers with marks that would go to the Corbeille, in street
  /// order.
  final List<HouseNumber> numbers;

  /// How many they are, for « 3 numéros ont des marques ».
  int get count => numbers.length;

  @override
  bool operator ==(Object other) =>
      other is MarkedNumbersLeaving && sameItems(other.numbers, numbers);

  @override
  int get hashCode => Object.hashAll(numbers);

  @override
  String toString() =>
      'MarkedNumbersLeaving(${numbers.map((number) => number.label).join(', ')})';
}

/// The new part holds numbers the street does not have, and the BAN could
/// not give them, for [reason]: [AddressDirectoryFailure.noNetwork] is
/// « Connexion nécessaire… », the others « Impossible de … pour
/// l'instant ».
final class NumbersUnreadable extends PartChangeRefusal {
  const NumbersUnreadable(this.reason);

  final AddressDirectoryFailure reason;

  @override
  bool operator ==(Object other) =>
      other is NumbersUnreadable && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'NumbersUnreadable($reason)';
}

/// « Valider » on « Partie de la rue » in edit mode (PLAN §5.15): gives
/// the street a new part, as the member on the phone, now
/// (`Street.changePart`).
///
/// - **Shrinking** sends the numbers left out to the Corbeille with their
///   marks. When some have marks, it first changes nothing and says which
///   ([MarkedNumbersLeaving]); the screen asks, then calls again with
///   `marksConfirmed: true`. It needs no network.
/// - **Widening** brings back the numbers of the Corbeille now inside, and
///   adds the others the BAN gives for the stretch brought in: it reads the
///   street's numbers again, the only read after the street was added
///   (PLAN §5.15). Offline it changes nothing ([NumbersUnreadable]). A
///   street typed by hand has no BAN street: only the Corbeille brings
///   numbers back.
///
/// Returns the change, which cannot be undone with « Annuler ».
final class ChangeStreetPart {
  const ChangeStreetPart(
    this._streets,
    this._directory,
    this._clock,
    this._identity,
  );

  final StreetRepository _streets;
  final AddressDirectory _directory;
  final Clock _clock;
  final IdentityProvider _identity;

  Future<Result<StreetPartChanged, PartChangeRefusal>> call(
    StreetId streetId,
    StreetPart part, {
    bool marksConfirmed = false,
  }) async {
    final street = await _streets.find(streetId);
    if (street == null) return const Err(PartOfUnknownStreet());
    if (street.part == part) return const Err(SamePart());
    if (!marksConfirmed) {
      final marked = [
        for (final house in street.housesLeftOutBy(part))
          if (house.hasMarks) house.number,
      ];
      if (marked.isNotEmpty) return Err(MarkedNumbersLeaving(marked));
    }

    var fromDirectory = const <House>[];
    final banId = street.banId;
    if (!part.isWithin(street.part) && banId != null) {
      switch (await _directory.numbersOf(banId)) {
        case Err(:final failure):
          return Err(NumbersUnreadable(failure));
        case Ok(value: final numbers):
          fromDirectory = [
            for (final number in numbers.numbers)
              House(number: number.number, position: number.position),
          ];
      }
    }

    // Read again by `runOnStreet`: a teammate's change may have arrived
    // while the BAN answered, and must not be lost.
    final by = _identity.currentMember;
    final at = _clock.now();
    final changed = await runOnStreet(
      _streets,
      streetId,
      (street) =>
          street.changePart(part, fromDirectory: fromDirectory, by: by, at: at),
    );
    return switch (changed) {
      Ok(:final value) => Ok(value),
      Err(failure: StreetNotFound()) => const Err(PartOfUnknownStreet()),
      Err(failure: CommandRefused(reason: PartChangeFailure.samePart)) =>
        const Err(SamePart()),
    };
  }
}

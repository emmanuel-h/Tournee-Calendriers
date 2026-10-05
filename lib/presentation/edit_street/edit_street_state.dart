import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';

// The view state of the edit mode of a street (PLAN §5.5, mockup Edit), and
// what its commands answer, so the screen knows whether to ask first, show
// « Annuler », or say why nothing changed.

/// One dashed tile of the edit mode: « 3 », or « 8 · immeuble ».
final class EditTile {
  const EditTile({required this.number, required this.isBuilding});

  /// The tile of [house].
  factory EditTile.of(House house) =>
      EditTile(number: house.number, isBuilding: house.isBuilding);

  final HouseNumber number;

  /// The house is a building: the tile says so, and its sheet offers
  /// « Modifier les étages » and « Redevenir une maison ».
  final bool isBuilding;

  @override
  bool operator ==(Object other) =>
      other is EditTile &&
      other.number == number &&
      other.isBuilding == isBuilding;

  @override
  int get hashCode => Object.hash(number, isBuilding);

  @override
  String toString() =>
      'EditTile(${number.label}${isBuilding ? ', building' : ''})';
}

/// Everything the edit mode shows. `sealed`: the screen handles each case.
sealed class EditStreetState {
  const EditStreetState();
}

/// The street is being read from the phone (a moment, at most).
final class EditStreetLoading extends EditStreetState {
  const EditStreetLoading();
}

/// No such street on the phone, or it went to the Corbeille.
final class EditStreetGone extends EditStreetState {
  const EditStreetGone();
}

/// The street's name and numbers, side by side as on the street screen.
final class EditStreetShown extends EditStreetState {
  EditStreetShown({
    required this.name,
    required this.columns,
    required List<EditTile> odd,
    required List<EditTile> even,
  }) : odd = List.unmodifiable(odd),
       even = List.unmodifiable(even);

  /// The name as stored; the name field starts from it.
  final String name;

  /// One column when the street has numbers on one side only, as on the
  /// street screen.
  final StreetColumns columns;

  /// The tiles of each side, in street order (`3 < 3bis < 3A < 4`).
  final List<EditTile> odd;
  final List<EditTile> even;

  /// The tile of [number], or null when the street no longer shows it.
  EditTile? tileOf(HouseNumber number) {
    for (final tile in [...odd, ...even]) {
      if (tile.number == number) return tile;
    }
    return null;
  }
}

/// What ✕ or « Redevenir une maison » did. `sealed`: the screen handles
/// each case.
sealed class EditOutcome {
  const EditOutcome();
}

/// The change is stored; « Annuler » can undo it.
final class EditApplied extends EditOutcome {
  const EditApplied();
}

/// Nothing was stored: marks would go with the change (PLAN §5.5). The
/// screen asks, then tries again, confirmed.
final class EditNeedsConfirmation extends EditOutcome {
  const EditNeedsConfirmation();
}

/// Nothing was stored: the number or the street is no longer there (or no
/// longer a building).
final class EditFailed extends EditOutcome {
  const EditFailed();
}

/// What « Changer le numéro » did. `sealed`: the sheet handles each case.
sealed class RenumberOutcome {
  const RenumberOutcome();
}

/// The house now has [newNumber], its marks kept; « Annuler » can undo it.
final class Renumbered extends RenumberOutcome {
  const Renumbered(this.newNumber);

  final HouseNumber newNumber;

  @override
  bool operator ==(Object other) =>
      other is Renumbered && other.newNumber == newNumber;

  @override
  int get hashCode => newNumber.hashCode;

  @override
  String toString() => 'Renumbered(${newNumber.label})';
}

/// The text typed is not a house number, for [reason].
final class RenumberInvalid extends RenumberOutcome {
  const RenumberInvalid(this.reason);

  final HouseNumberFailure reason;

  @override
  bool operator ==(Object other) =>
      other is RenumberInvalid && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'RenumberInvalid($reason)';
}

/// The number typed is the one the house already has: nothing to do.
final class RenumberUnchanged extends RenumberOutcome {
  const RenumberUnchanged();
}

/// Another house of the street shows [number].
final class RenumberTaken extends RenumberOutcome {
  const RenumberTaken(this.number);

  final HouseNumber number;

  @override
  bool operator ==(Object other) =>
      other is RenumberTaken && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'RenumberTaken(${number.label})';
}

/// A house in the Corbeille has [number]: « + numéros » brings it back, or
/// another number must be chosen.
final class RenumberInCorbeille extends RenumberOutcome {
  const RenumberInCorbeille(this.number);

  final HouseNumber number;

  @override
  bool operator ==(Object other) =>
      other is RenumberInCorbeille && other.number == number;

  @override
  int get hashCode => number.hashCode;

  @override
  String toString() => 'RenumberInCorbeille(${number.label})';
}

/// The house or the street is no longer there: nothing stored.
final class RenumberFailed extends RenumberOutcome {
  const RenumberFailed();
}

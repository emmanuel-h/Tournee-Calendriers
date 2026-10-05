import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';

// The view state of the « Ajouter des numéros » sheet (PLAN §5.5, mockup
// Numbers): the preview is computed at each key, before anything is added.

/// What the « Numéros » field gives so far. `sealed`: the sheet handles
/// each case.
sealed class NumbersPreview {
  const NumbersPreview();
}

/// The field is blank (or holds only separators): no preview, nothing to
/// add.
final class NothingTyped extends NumbersPreview {
  const NothingTyped();
}

/// One item of the field is wrong: the [failure] names it.
final class NumbersRefused extends NumbersPreview {
  const NumbersRefused(this.failure);

  final NumbersFailure failure;
}

/// « Aperçu · 6 numéros »: the [numbers] typed, in street order, and how
/// the street takes them.
final class NumbersPreviewed extends NumbersPreview {
  NumbersPreviewed({
    required List<HouseNumber> numbers,
    required List<HouseNumber> alreadyThere,
    required List<HouseNumber> fromCorbeille,
  }) : numbers = List.unmodifiable(numbers),
       alreadyThere = List.unmodifiable(alreadyThere),
       fromCorbeille = List.unmodifiable(fromCorbeille);

  final List<HouseNumber> numbers;

  /// The numbers the street already shows: they are skipped.
  final List<HouseNumber> alreadyThere;

  /// The numbers in the Corbeille: they come back with their marks.
  final List<HouseNumber> fromCorbeille;

  /// How many numbers « Ajouter » would show that are not shown now.
  int get newCount => numbers.length - alreadyThere.length;

  /// « Ajouter » changes something.
  bool get canAdd => newCount > 0;
}

/// Everything the sheet shows. `sealed`: the sheet handles each case.
sealed class AddNumbersState {
  const AddNumbersState();
}

/// The street is being read from the phone (a moment, at most).
final class AddNumbersLoading extends AddNumbersState {
  const AddNumbersLoading();
}

/// The street is no longer on the phone, or went to the Corbeille.
final class AddNumbersGone extends AddNumbersState {
  const AddNumbersGone();
}

/// The street's name under the title, and the preview of the field.
final class AddNumbersShown extends AddNumbersState {
  const AddNumbersShown({required this.streetName, required this.preview});

  final String streetName;
  final NumbersPreview preview;
}

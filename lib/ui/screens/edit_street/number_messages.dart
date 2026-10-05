import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';

/// Why [text] is not a house number, in French, naming what was typed
/// (the number sheet and « Ajouter des numéros »).
String houseNumberMessage(
  AppLocalizations l10n,
  String text,
  HouseNumberFailure reason,
) => switch (reason) {
  HouseNumberFailure.empty => l10n.numberEmpty,
  HouseNumberFailure.malformed ||
  HouseNumberFailure.negativeNumber => l10n.numberMalformed(text),
  HouseNumberFailure.numberTooLarge => l10n.numberTooLarge(
    text,
    HouseNumber.maxNumber,
  ),
  HouseNumberFailure.invalidSuffix => l10n.numberInvalidSuffix(text),
  HouseNumberFailure.suffixTooLong => l10n.numberSuffixTooLong(
    text,
    HouseNumber.maxSuffixLength,
  ),
};

/// Why the « Numéros » field gives no list, naming the wrong item.
String numbersMessage(AppLocalizations l10n, NumbersFailure failure) =>
    switch (failure) {
      InvalidNumber(:final token, :final reason) => houseNumberMessage(
        l10n,
        token,
        reason,
      ),
      InvalidRange(:final token) => l10n.numbersInvalidRange(token),
      // Only the manual street form has « Du » / « Au » fields; listed so
      // a new case of `NumbersFailure` must be phrased here.
      InvalidBound(:final text) => l10n.numberMalformed(text),
      TooManyNumbers() => l10n.numbersTooMany(maxNumbersAtOnce),
    };

/// The [numbers] on one line: all of them up to twelve, then the
/// first ten, « … » and the last, so a long range stays readable.
String shortNumberList(List<HouseNumber> numbers) {
  final labels = [for (final number in numbers) number.label];
  if (labels.length <= 12) return labels.join(', ');
  return '${labels.take(10).join(', ')} … ${labels.last}';
}

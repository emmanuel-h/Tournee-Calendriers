import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// Why a text cannot become a [DwellingLabel].
enum DwellingLabelFailure {
  /// Nothing but spaces.
  blank,

  /// More than [DwellingLabel.maxLength] characters once trimmed.
  tooLong,
}

/// What a door of a building shows: `51`, `5A`, or a typed label such as
/// `Gauche` (PLAN §5.7). It names the dwelling in its staircase, so two
/// doors of a staircase never share one.
///
/// The text is trimmed; case and inner spaces are kept, so `Gauche` and
/// `gauche` are two labels. Its length is counted by [characterCount].
final class DwellingLabel {
  const DwellingLabel._(this.text);

  /// Builds a label made by code (the layout generator, a storage adapter):
  /// such text is always valid, so an invalid one is a bug and throws an
  /// [ArgumentError]. Text typed by a person goes through [parse].
  factory DwellingLabel(String text) => switch (parse(text)) {
    Ok(:final value) => value,
    Err(:final failure) => throw ArgumentError.value(
      text,
      'text',
      failure.name,
    ),
  };

  /// The longest label, in characters: a door tile holds a short word
  /// (« Gauche », « Fond cour »), not a sentence.
  static const maxLength = 12;

  /// Reads a label typed by a person, or fails with a
  /// [DwellingLabelFailure].
  static Result<DwellingLabel, DwellingLabelFailure> parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const Err(DwellingLabelFailure.blank);
    if (characterCount(trimmed) > maxLength) {
      return const Err(DwellingLabelFailure.tooLong);
    }
    return Ok(DwellingLabel._(trimmed));
  }

  /// The trimmed text, never empty.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is DwellingLabel && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'DwellingLabel($text)';
}

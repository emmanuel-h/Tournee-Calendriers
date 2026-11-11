import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// Why a typed text cannot become a [MemberName].
enum MemberNameFailure {
  /// Nothing but spaces was typed, or nothing but separators (dashes,
  /// apostrophes, dots, underscores, slashes): nothing a [MemberName.key]
  /// could be made of.
  blank,

  /// More than [MemberName.maxLength] characters once cleaned.
  tooLong,
}

/// The first name a member gives on « Bienvenue » (« Manu », PLAN §5.1),
/// which the team sees in Équipe and on the marks they make.
///
/// Trimmed, each run of spaces made one, case and accents kept; 1 to
/// [maxLength] characters, counted as [characterCount] counts them.
///
/// Names are unique within a secteur, case and accents ignored (#148, PLAN
/// §5.16): two names are the same name there when their [key]s are equal.
final class MemberName {
  const MemberName._(this.text, this.key);

  /// The longest name, in characters: room for a compound first name and
  /// an initial, short enough for one line of Équipe. The security rules
  /// can enforce the same limit (PLAN §8.2).
  static const maxLength = 30;

  static final _spaces = RegExp(r'\s+');

  /// Builds the name from [text] once cleaned, or fails with a
  /// [MemberNameFailure].
  static Result<MemberName, MemberNameFailure> create(String text) {
    final cleaned = text.trim().replaceAll(_spaces, ' ');
    // Never holds a `/` nor is `.` or `__…__`, which a Firestore document
    // id may not be: `nameKey` reads them as spaces.
    final key = nameKey(cleaned);
    if (key.isEmpty) return const Err(MemberNameFailure.blank);
    if (characterCount(cleaned) > maxLength) {
      return const Err(MemberNameFailure.tooLong);
    }
    return Ok(MemberName._(cleaned, key));
  }

  /// The cleaned name, never empty.
  final String text;

  /// The form under which the name is unique in a secteur (`nameKey`):
  /// A to Z lowered, the French accents dropped, dashes, apostrophes,
  /// dots, underscores and slashes read as spaces, single spaces, trimmed
  /// (« Léa », « LÉA » → `lea`; « Jean-Paul » → `jean paul`). Never empty.
  ///
  /// The security rules work it out the same way (`nameKey` in
  /// `firebase/firestore.rules`) and hold each member's name under it.
  final String key;

  @override
  bool operator ==(Object other) => other is MemberName && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MemberName($text)';
}

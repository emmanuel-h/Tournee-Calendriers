import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// Why a text cannot become a [StreetName].
enum StreetNameFailure {
  /// Nothing but spaces was typed.
  blank,

  /// More than [StreetName.maxLength] characters once cleaned.
  tooLong,
}

/// The name of a street (« Chemin des Vignes »), as typed in the manual
/// street form or the name field of the edit mode (PLAN §5.5), or as the
/// address base (BAN) gives it.
///
/// A name is one line: it is trimmed, and each run of spaces, tabs or line
/// breaks inside becomes one space, so « Rue  des Lilas » typed with two
/// spaces is the same street name as « Rue des Lilas ». Case and accents
/// are kept as typed. It holds 1 to [maxLength] characters, counted as
/// [characterCount] counts them.
final class StreetName {
  const StreetName._(this.text);

  /// The longest name, in characters. Street names of the BAN stay well
  /// under it, so no real street is refused, and the security rules can
  /// enforce the same limit on the stored name (PLAN §8.2).
  static const maxLength = 150;

  static final _spaces = RegExp(r'\s+');

  /// Builds the name from [text] once cleaned, or fails with a
  /// [StreetNameFailure].
  static Result<StreetName, StreetNameFailure> create(String text) {
    final cleaned = text.trim().replaceAll(_spaces, ' ');
    if (cleaned.isEmpty) return const Err(StreetNameFailure.blank);
    if (characterCount(cleaned) > maxLength) {
      return const Err(StreetNameFailure.tooLong);
    }
    return Ok(StreetName._(cleaned));
  }

  /// The cleaned name, never empty.
  final String text;

  /// Whether [other], a name as another source writes it (a road of
  /// OpenStreetMap), names this street: the same words, ignoring case,
  /// accents, the kind of apostrophe and hyphens against spaces (see
  /// `searchKey`). The BAN often leaves the accents out: « Rue du Musee »
  /// is « Rue du Musée » on the map. The whole name must match: « Rue
  /// Nationale » is not « Rue Nationale Prolongée ».
  bool matches(String other) => searchKey(other) == searchKey(text);

  @override
  bool operator ==(Object other) => other is StreetName && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'StreetName($text)';
}

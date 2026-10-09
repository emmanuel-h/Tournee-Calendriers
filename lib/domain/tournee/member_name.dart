import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// Why a typed text cannot become a [MemberName].
enum MemberNameFailure {
  /// Nothing but spaces was typed.
  blank,

  /// More than [MemberName.maxLength] characters once cleaned.
  tooLong,
}

/// The first name a member gives on « Bienvenue » (« Manu », PLAN §5.1),
/// which the team sees in Équipe and on the marks they make.
///
/// Trimmed, each run of spaces made one, case and accents kept; 1 to
/// [maxLength] characters, counted as [characterCount] counts them.
final class MemberName {
  const MemberName._(this.text);

  /// The longest name, in characters: room for a compound first name and
  /// an initial, short enough for one line of Équipe. The security rules
  /// can enforce the same limit (PLAN §8.2).
  static const maxLength = 30;

  static final _spaces = RegExp(r'\s+');

  /// Builds the name from [text] once cleaned, or fails with a
  /// [MemberNameFailure].
  static Result<MemberName, MemberNameFailure> create(String text) {
    final cleaned = text.trim().replaceAll(_spaces, ' ');
    if (cleaned.isEmpty) return const Err(MemberNameFailure.blank);
    if (characterCount(cleaned) > maxLength) {
      return const Err(MemberNameFailure.tooLong);
    }
    return Ok(MemberName._(cleaned));
  }

  /// The cleaned name, never empty.
  final String text;

  @override
  bool operator ==(Object other) => other is MemberName && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MemberName($text)';
}

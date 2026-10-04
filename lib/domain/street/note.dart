import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// Why a text cannot become a [Note].
enum NoteFailure {
  /// More than [Note.maxLength] characters once trimmed.
  tooLong,
}

/// The free note on a house or a dwelling (« chien dans le jardin »).
///
/// Its text is trimmed (spaces and line breaks around it are dropped; line
/// breaks inside are kept) and holds at most [maxLength] characters as
/// counted by [characterCount]. A house without a note holds [Note.empty].
final class Note {
  const Note._(this.text);

  /// The note of a house nobody wrote anything about.
  static const empty = Note._('');

  /// The longest note, in characters (PLAN §6.1). The security rules
  /// enforce the same limit (PLAN §8.2).
  static const maxLength = 200;

  /// Builds the note holding [text] once trimmed, or fails with
  /// [NoteFailure.tooLong].
  ///
  /// A static method rather than a constructor, because a constructor cannot
  /// return a failure.
  static Result<Note, NoteFailure> create(String text) {
    final trimmed = text.trim();
    if (characterCount(trimmed) > maxLength) {
      return const Err(NoteFailure.tooLong);
    }
    return Ok(Note._(trimmed));
  }

  /// The trimmed text; empty when there is no note.
  final String text;

  @override
  bool operator ==(Object other) => other is Note && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'Note($text)';
}

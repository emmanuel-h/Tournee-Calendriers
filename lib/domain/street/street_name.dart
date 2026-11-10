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

  /// The small words of a street name, which a map often gets wrong
  /// (« Rue de le Paix » for « Rue de la Paix ») or leaves out, and which
  /// never tell two streets apart on their own.
  static const _smallWords = {
    'a', 'au', 'aux', 'd', 'de', 'des', 'du', 'et', 'l', 'la', 'le', 'les', //
  };

  /// The shortest word in which [typosFrom] allows one letter off. A short
  /// word one letter off is often another street (« Rue de la Mare », « Rue
  /// de la Gare »); a long one rarely is (« Pasteur », « Pasteir »).
  static const _longWordLength = 7;

  /// How many letters [other], a name as another source writes it (a road
  /// of OpenStreetMap), is away from this name, when it is close enough to
  /// be this street misspelt (#134); null when it is not.
  ///
  /// 0 when it [matches]. Otherwise it is close when, leaving the small
  /// words out (« de », « la », « du »…: they may differ, be missing or be
  /// added), the other words are the same, in the same order, except at
  /// most one word of [_longWordLength] letters or more (both spellings)
  /// that is one letter off. The count is then [editDistance] of both
  /// names, as [searchKey] writes them, so that the closest of several
  /// names can be told (`closestNamed`).
  ///
  /// So « Rue de le Paix » is « Rue de la Paix » (1), but « Rue de la
  /// Gare » is not, nor « Impasse de la Paix », nor « Rue Nationale
  /// Prolongée »: a word that carries the name must be there and spelt the
  /// same, bar one letter of a long one.
  int? typosFrom(String other) {
    final mine = searchKey(text);
    final theirs = searchKey(other);
    if (mine == theirs) return 0;
    final myWords = _mainWords(mine);
    final theirWords = _mainWords(theirs);
    if (myWords.length != theirWords.length) return null;
    var longWordsOff = 0;
    for (var i = 0; i < myWords.length; i++) {
      final (a, b) = (myWords[i], theirWords[i]);
      if (a == b) continue;
      final long = a.length >= _longWordLength && b.length >= _longWordLength;
      if (!long || editDistance(a, b) > 1) return null;
      longWordsOff++;
    }
    if (longWordsOff > 1) return null;
    return editDistance(mine, theirs);
  }

  static List<String> _mainWords(String key) => [
    for (final word in key.split(' '))
      if (!_smallWords.contains(word)) word,
  ];

  @override
  bool operator ==(Object other) => other is StreetName && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'StreetName($text)';
}

/// The one of [streets] that [name] (a road of the map) names, by
/// `nameOf` each: the first that [StreetName.matches] it, else the one
/// with the fewest [StreetName.typosFrom] it; null when none is close, or
/// when two different names are as close (better no street than another
/// one than the road tapped). Two of [streets] of the same name count as
/// one: the first is taken.
T? closestNamed<T>(
  String name,
  Iterable<T> streets,
  StreetName Function(T street) nameOf,
) {
  T? closest;
  int? fewest;
  var tied = false;
  for (final street in streets) {
    final typos = nameOf(street).typosFrom(name);
    if (typos == null) continue;
    if (typos == 0) return street;
    if (fewest == null || typos < fewest) {
      (closest, fewest, tied) = (street, typos, false);
    } else if (typos == fewest && nameOf(street) != nameOf(closest as T)) {
      tied = true;
    }
  }
  return tied ? null : closest;
}

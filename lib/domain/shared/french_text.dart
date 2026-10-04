// How French names are compared and searched (street and commune names):
// a domain service of pure functions.
//
// People type without accents or capitals on a phone, and expect
// « Église » to sort with the E's, not after Z (where a plain comparison of
// character codes puts it). Both the order and the filter therefore work on
// a *search key*: the name lowered, without accents, ligatures spelled out,
// hyphens and apostrophes read as spaces.

/// Each accented letter (lower case) and the plain letters it stands for.
const _plainLetters = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a', 'å': 'a', //
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i', 'ì': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o', 'ò': 'o', 'õ': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'ý': 'y',
  'ñ': 'n',
  'œ': 'oe', 'æ': 'ae',
  // Read as spaces: « Saint-Roch » is found by « saint roch ».
  '-': ' ', "'": ' ', '’': ' ',
};

/// Accents typed as a separate mark after the letter (U+0300 to U+036F),
/// as some keyboards and copied texts do.
bool _isCombiningMark(int rune) => rune >= 0x0300 && rune <= 0x036F;

final _spaces = RegExp(r'\s+');

/// The form of [text] that comparisons and filters use: lower case, without
/// accents (`é` → `e`, `œ` → `oe`), hyphens and apostrophes made spaces,
/// trimmed, each run of spaces made one.
String searchKey(String text) {
  final key = StringBuffer();
  // `runes` walks the text by Unicode code point, so a letter outside the
  // basic plane is never cut in two.
  for (final rune in text.toLowerCase().runes) {
    if (_isCombiningMark(rune)) continue;
    final letter = String.fromCharCode(rune);
    key.write(_plainLetters[letter] ?? letter);
  }
  return key.toString().trim().replaceAll(_spaces, ' ');
}

/// Orders [a] and [b] the way a French reader expects, ignoring case and
/// accents. Two names that differ only by them compare equal: the caller
/// decides what comes first then (an id, for a stable order).
int compareFrench(String a, String b) => searchKey(a).compareTo(searchKey(b));

/// Whether [text] holds what was typed in a filter box, ignoring case and
/// accents. A blank [filter] matches everything.
bool matchesFilter(String text, String filter) =>
    searchKey(text).contains(searchKey(filter));

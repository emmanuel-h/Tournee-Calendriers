import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/shared/text_length.dart';

/// Why a typed name cannot become a [RescueCentre].
enum RescueCentreFailure {
  /// Nothing names the station once the « CS » / « CIS » / « centre de
  /// secours » prefix, spaces and punctuation are set aside.
  blank,

  /// More than [RescueCentre.maxLength] characters once cleaned.
  tooLong,
}

/// The fire station a tournée belongs to (« CS Villefranche », PLAN §2,
/// §5.2): its [name] as people wrote it, and the [key] that tells whether
/// two names are the same station.
///
/// A tournée is identified by its number *and* its centre de secours, so
/// « CS Villefranche » and « CIS villefranche » must not become two
/// stations with a tournée 49 each: they share a key.
final class RescueCentre {
  const RescueCentre._(this.name, this.key);

  /// The longest name, in characters (code points, as [characterCount]
  /// counts them). « Centre d'incendie et de secours de » and a long
  /// commune name stay under it; the security rules can enforce the same
  /// limit (PLAN §8.2).
  static const maxLength = 80;

  static final _spaces = RegExp(r'\s+');

  /// Builds the station from a typed or stored [name]: trimmed, each run of
  /// spaces made one, case and accents kept. Fails with a
  /// [RescueCentreFailure] when it is too long or names nothing.
  static Result<RescueCentre, RescueCentreFailure> create(String name) {
    final cleaned = name.trim().replaceAll(_spaces, ' ');
    if (characterCount(cleaned) > maxLength) {
      return const Err(RescueCentreFailure.tooLong);
    }
    final key = RescueCentreKey._of(cleaned);
    if (key == null) return const Err(RescueCentreFailure.blank);
    return Ok(RescueCentre._(cleaned, key));
  }

  /// The name as typed, cleaned: what the screens show (« CS
  /// Villefranche »).
  final String name;

  /// What identifies the station (see [RescueCentreKey]).
  final RescueCentreKey key;

  /// Whether [other] is the same station written another way (« CIS
  /// Villefranche » for « CS Villefranche »).
  bool isSameStationAs(RescueCentre other) => other.key == key;

  /// Equal when the names are equal: two ways of writing one station are
  /// not the same value, see [isSameStationAs].
  @override
  bool operator ==(Object other) =>
      other is RescueCentre && other.name == name && other.key == key;

  @override
  int get hashCode => Object.hash(name, key);

  @override
  String toString() => 'RescueCentre($name)';
}

/// The normalised name of a [RescueCentre], such as `villefranche` or
/// `villefranche-sur-saone`: two names with the same key are one station.
///
/// It is the station's identity in storage (`rescueCentres/villefranche`,
/// and with the tournée number `tourneeKeys/villefranche_49`, PLAN §6.2),
/// so it holds only `a`–`z`, `0`–`9` and single dashes between words: safe
/// in a document path.
final class RescueCentreKey {
  const RescueCentreKey._(this.value);

  /// The prefixes that say « fire station » rather than which one, as words
  /// of a search key (the apostrophe of « d'incendie » is a space there).
  static const _prefixes = [
    ['centre', 'd', 'incendie', 'et', 'de', 'secours'],
    ['centre', 'de', 'secours'],
    ['cis'],
    ['cs'],
  ];

  /// The words that join a prefix to the place: « CS de Villefranche » is
  /// « CS Villefranche ».
  static const _articles = {'de', 'd', 'du', 'des'};

  static final _notLetterOrDigit = RegExp('[^a-z0-9]+');

  /// The key of [name], or null when nothing is left of it.
  ///
  /// The name goes through [searchKey] (lower case, accents dropped,
  /// hyphens and apostrophes made spaces), is cut into words of letters and
  /// digits (other punctuation is a separator too), loses one leading
  /// prefix and the article after it, and the words are joined with dashes.
  static RescueCentreKey? _of(String name) {
    final words = searchKey(name)
        .split(_notLetterOrDigit)
        .where((word) => word.isNotEmpty)
        .toList();
    final place = _withoutPrefix(words);
    if (place.isEmpty) return null;
    return RescueCentreKey._(place.join('-'));
  }

  static List<String> _withoutPrefix(List<String> words) {
    for (final prefix in _prefixes) {
      if (!_startsWith(words, prefix)) continue;
      final rest = words.sublist(prefix.length);
      // A lone article after the prefix (« CS Des ») is then the name.
      if (rest.length > 1 && _articles.contains(rest.first)) {
        return rest.sublist(1);
      }
      return rest;
    }
    return words;
  }

  static bool _startsWith(List<String> words, List<String> prefix) {
    if (words.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (words[i] != prefix[i]) return false;
    }
    return true;
  }

  /// Lower-case letters and digits, words joined by single dashes; never
  /// empty.
  final String value;

  @override
  bool operator ==(Object other) =>
      other is RescueCentreKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'RescueCentreKey($value)';
}

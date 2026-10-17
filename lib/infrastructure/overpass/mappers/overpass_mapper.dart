// The Overpass query that asks OpenStreetMap for a street's roads, and the
// translation of its answer (already decoded from JSON) into a StreetShape.
// Pure functions: no HTTP here, so they are tested alone on the captured
// fixtures (test/fixtures/overpass/).
//
// Overpass speaks its own query language (Overpass QL): a statement per
// line, ending with `;`. Strings are written between double quotes, where a
// quote or a backslash is escaped with a backslash.
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// How long the server may work on the query, in seconds, before it gives
/// up (the answer is then a runtime error, read as a failure). A street is
/// found in about a second; a busy server queues it.
const overpassTimeoutSeconds = 15;

/// Each plain vowel or `c` with the letters OpenStreetMap may write in its
/// place, accented or not, lower and upper case.
const _letterVariants = [
  'aàâäAÀÂÄ',
  'cçCÇ',
  'eéèêëEÉÈÊË',
  'iîïIÎÏ',
  'oôöOÔÖ',
  'uùûüUÙÛÜ',
  'yÿYŸ',
];

/// For each of those letters, the alternation that matches any of its
/// family: `é` → `(e|é|è|ê|ë|E|É|È|Ê|Ë)`. Each letter is a single UTF-16
/// code unit, so `split('')` cuts the families letter by letter.
final _alternationOf = {
  for (final family in _letterVariants)
    for (final letter in family.split(''))
      letter: '(${family.split('').join('|')})',
};

/// The signs a regular expression gives a meaning to, escaped with a
/// backslash to stand for themselves.
const _regexSigns = r'.^$*+?()[]{}|\';

/// The regular expression that matches [name] as OpenStreetMap may write
/// it: the whole name, the vowels and `c` with or without accents (the BAN
/// often leaves them out: « Rue du Musee » for « Rue du Musée »), either
/// apostrophe (`'` or `’`), a hyphen or a space where the other is.
///
/// The query adds the `i` flag for the case of the other letters. Each
/// family is an alternation rather than a bracket class (`[eé]`), which a
/// regular expression engine may read byte by byte (an accented letter is
/// two bytes in UTF-8); the alternation was checked on the real server.
String streetNamePattern(StreetName name) {
  final pattern = StringBuffer('^');
  // `runes` gives the characters one by one, even one written with two
  // UTF-16 code units.
  for (final rune in name.text.runes) {
    final character = String.fromCharCode(rune);
    pattern.write(switch (character) {
      "'" || '’' => "('|’)",
      '-' || ' ' => '(-| )',
      _ when _alternationOf.containsKey(character) => _alternationOf[character],
      _ when _regexSigns.contains(character) => '\\$character',
      _ => character,
    });
  }
  pattern.write(r'$');
  return pattern.toString();
}

/// The Overpass query for the roads named [name] in the commune [commune]:
/// the ways tagged `highway` (any kind of road or path) whose `name`
/// matches [streetNamePattern], inside the commune's administrative
/// boundary (found by its INSEE code), with their points (`out geom`).
String overpassStreetQuery(StreetName name, InseeCode commune) {
  // Backslashes first, so the ones added before the quotes stay single.
  final quoted = streetNamePattern(name)
      .replaceAll(r'\', r'\\')
      .replaceAll('"', r'\"');
  return '[out:json][timeout:$overpassTimeoutSeconds];\n'
      'area["ref:INSEE"="${commune.value}"]["boundary"="administrative"]'
      '["admin_level"="8"]->.commune;\n'
      'way(area.commune)["highway"]["name"~"$quoted",i];\n'
      'out geom;';
}

/// Reads the answer of [overpassStreetQuery]: one line a way, in the order
/// the server gives them, each point in the order the road runs. No way
/// means [StreetShape.none].
///
/// An element that is not a way, or has a point that is not a valid
/// `{lat, lon}`, is left out (a way of one point too, by [StreetShape]).
///
/// Throws a [FormatException] when [json] is not an Overpass answer, or
/// when it carries a `remark`: the server stopped on an error (a timeout,
/// too little memory) and what it gives may be incomplete.
StreetShape streetShapeFromJson(Object? json) {
  if (json case {'elements': final List<Object?> elements}) {
    if (json case {'remark': final Object remark}) {
      throw FormatException('Overpass stopped', remark);
    }
    return StreetShape([for (final element in elements) ?_line(element)]);
  }
  throw const FormatException('Not an Overpass answer');
}

/// The points of one element, or null when it is not a readable way.
List<GeoPoint>? _line(Object? element) {
  if (element case {'type': 'way', 'geometry': final List<Object?> nodes}) {
    final points = <GeoPoint>[];
    for (final node in nodes) {
      final point = _point(node);
      // One unreadable point would draw the road elsewhere: leave the way.
      if (point == null) return null;
      points.add(point);
    }
    return points;
  }
  return null;
}

GeoPoint? _point(Object? node) {
  if (node case {'lat': final num latitude, 'lon': final num longitude}) {
    return switch (GeoPoint.create(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    )) {
      Ok(:final value) => value,
      Err() => null,
    };
  }
  return null;
}

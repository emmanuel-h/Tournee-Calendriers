import 'dart:math' as math;

import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/geometry/geo_distance.dart';
import 'package:tournee_calendriers/domain/geometry/line_track.dart';
import 'package:tournee_calendriers/domain/map/part_drawing.dart';
import 'package:tournee_calendriers/domain/shared/geo_point.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';

/// A number of a street with where its entrance is, when known: what
/// « Partie de la rue » chooses among (PLAN §5.15).
final class PartNumber {
  const PartNumber(this.number, {this.position});

  final HouseNumber number;

  /// Null for a number typed by hand: it is kept or left out by its number
  /// alone, with no dot on the map.
  final GeoPoint? position;

  @override
  bool operator ==(Object other) =>
      other is PartNumber &&
      other.number == number &&
      other.position == position;

  @override
  int get hashCode => Object.hash(number, position);

  @override
  String toString() => 'PartNumber(${number.label}, $position)';
}

/// One of the two marks of « Partie de la rue »: the [first] and the
/// [last] along the road. The first never passes the last.
enum PartMark { first, last }

/// A number of a side as a mark sees it: its [value] (`3` for 3 and
/// 3bis, which a part never parts), and how far [along] the road its dots
/// are (the mean, when 3 and 3bis have two).
typedef _Stop = ({bool isOdd, int value, double along});

/// The part of a street being chosen on « Partie de la rue » (PLAN §5.15):
/// every number of the street with its position, the road, the side shown
/// (« Les deux | Impairs | Pairs ») and the [part] chosen so far.
///
/// Two marks stand on the road between two consecutive dots of the side
/// shown (on « Les deux », of both sides); the numbers between them are
/// kept. Moving a mark works the part out again, side by side: nothing
/// kept is « aucun », both ends kept is « tous », otherwise the numbers
/// from the lowest kept to the highest. A mark at an end takes the
/// numbers with no position beyond the last dot with it (« du n° 1 »).
///
/// Immutable: each change returns a new choice. The screen gives back
/// [part]; storing it is the caller's (`ChangeStreetPart` in edit mode).
final class StreetPartChoice {
  StreetPartChoice._(
    this._track,
    this._stops, {
    required this.numbers,
    required this.road,
    required this.part,
    required this.side,
    required this.first,
    required this.last,
  });

  /// The choice over [numbers] (in any order; a number given twice is kept
  /// once, with its first position), along [road], starting from [part],
  /// both sides shown.
  ///
  /// The marks need a line to slide along: the [road], or, for a street
  /// whose road is not known, the straight line between its two dots
  /// farthest apart. With no dot, or a single place, there is no map
  /// ([drawing] is null): the part is chosen with [withBounds].
  factory StreetPartChoice.start({
    required Iterable<PartNumber> numbers,
    required StreetShape road,
    required StreetPart part,
  }) {
    final byNumber = <HouseNumber, PartNumber>{};
    for (final number in numbers) {
      byNumber.putIfAbsent(number.number, () => number);
    }
    final sorted = byNumber.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final track = _trackFor(road, sorted);
    return StreetPartChoice._(
      track,
      track == null ? const [] : _stopsAlong(track, sorted),
      numbers: List.unmodifiable(sorted),
      road: road,
      part: part,
      side: Sides.both,
      first: 0,
      last: 0,
    )._marked();
  }

  /// Every number of the street, sorted, each once.
  final List<PartNumber> numbers;

  /// The street's road; [StreetShape.none] when it is not known.
  final StreetShape road;

  /// The part chosen so far.
  final StreetPart part;

  /// The side shown: [Sides.both], or one side with its own marks.
  final Sides side;

  /// Where the marks stand: indexes of [PartDrawing.gaps], [first] ≤
  /// [last]; the dots of the side shown between them are kept.
  final int first;
  final int last;

  final LineTrack? _track;

  /// The numbers with a dot, along the road (by number where two are at the
  /// same place).
  final List<_Stop> _stops;

  /// From the first dot, a mark at an end stands this far beyond it.
  static const _endMetres = 8.0;

  /// The map shows this much of the road beyond the first and last dots.
  static const _aroundMetres = 20.0;

  /// How many numbers the part keeps (« 23 numéros gardés sur 41 »).
  int get keptCount =>
      numbers.where((number) => part.holds(number.number)).length;

  /// How many numbers the street has.
  int get numberCount => numbers.length;

  /// The lowest number of the street and the highest, their integer parts
  /// (« n° 1 à 41 »); null when it has none.
  int? get lowest => numbers.isEmpty ? null : numbers.first.number.number;
  int? get highest => numbers.isEmpty ? null : numbers.last.number.number;

  /// What the « Du n° » and « Au n° » fields show for the side shown: the
  /// bounds of its range (on « Les deux », from the lowest bound of the two
  /// sides to the highest); null where a side is whole or empty.
  ({int? from, int? to}) get bounds {
    final ranges = _sidesShown
        .map((isOdd) => _sideOf(part, isOdd: isOdd))
        .whereType<NumberRange>();
    if (ranges.isEmpty) return (from: null, to: null);
    return (
      from: ranges.map((range) => range.from).reduce(math.min),
      to: ranges.map((range) => range.to).reduce(math.max),
    );
  }

  /// The same part, the [side] shown, with its marks where the part puts
  /// them.
  StreetPartChoice withSide(Sides side) => _with(side: side);

  /// [mark] moved to the [gap]-th place of [PartDrawing.gaps] (kept within
  /// them, and not past the other mark), and the part worked out again for
  /// the side shown, from the dots between the marks. On « Les deux », a
  /// side without any dot keeps its part.
  StreetPartChoice withMark(PartMark mark, int gap) {
    final shown = _shown;
    final at = gap.clamp(0, shown.length);
    final (newFirst, newLast) = switch (mark) {
      PartMark.first => (math.min(at, last), last),
      PartMark.last => (first, math.max(at, first)),
    };
    if (newFirst == first && newLast == last) return this;
    final kept = shown.sublist(newFirst, newLast);
    SidePart sideFrom(bool isOdd) => _shown.any((stop) => stop.isOdd == isOdd)
        ? _sideKeeping(kept, isOdd: isOdd)
        : _sideOf(part, isOdd: isOdd);
    return StreetPartChoice._(
      _track,
      _stops,
      numbers: numbers,
      road: road,
      part: _part(odd: sideFrom(true), even: sideFrom(false)),
      side: side,
      first: newFirst,
      last: newLast,
    );
  }

  /// « Toute la rue » on « Les deux », « Tous les impairs » or « Tous les
  /// pairs » on one side.
  StreetPartChoice holdingAll() => _withSidesShown((_) => SidePart.all);

  /// « Rien » on « Les deux », « Aucun impair » or « Aucun pair » on one
  /// side.
  StreetPartChoice holdingNothing() => _withSidesShown((_) => SidePart.none);

  /// « Du n° [from] au n° [to] » for the side shown (both sides on « Les
  /// deux »), each bound brought onto the side (« du 6 » is « du 7 » on the
  /// odd side). A blank bound is the side's lowest or highest number; both
  /// blank keep the whole side. A bound above [HouseNumber.maxNumber] is
  /// that number.
  StreetPartChoice withBounds({int? from, int? to}) =>
      _withSidesShown((isOdd) => _bounded(from, to, isOdd: isOdd));

  /// What the map draws, or null when there is no map: a street without a
  /// dot, or with a single place and no road (see [StreetPartChoice.start]).
  PartDrawing? get drawing {
    final track = _track;
    if (track == null || _stops.isEmpty) return null;
    final shown = _shown;
    final marked = shown.isNotEmpty;
    final gaps = [
      if (marked)
        for (var gap = 0; gap <= shown.length; gap++)
          track.pointAt(_alongOf(gap)),
    ];
    final dots = [
      for (final number in numbers)
        if (number.position case final position?)
          PartDot(
            number: number.number,
            position: position,
            look: _lookOf(number),
          ),
    ];
    final drawnRoad = road.isEmpty ? StreetShape([track.points]) : road;
    PartMarkAt? markAt(int gap) => marked
        ? PartMarkAt(gap: gap, point: gaps[gap], place: _placeOf(gap))
        : null;
    return PartDrawing(
      road: drawnRoad,
      kept: marked && first < last
          ? StreetShape([track.between(_alongOf(first), _alongOf(last))])
          : StreetShape.none,
      dots: dots,
      gaps: gaps,
      first: markAt(first),
      last: markAt(last),
      // The dots and the road around them, not the whole road: a long road
      // would shrink the dots to nothing. Not null: there is a dot.
      area: GeoBounds.around([
        ...track.between(
          _stops.first.along - _aroundMetres,
          _stops.last.along + _aroundMetres,
        ),
        for (final dot in dots) dot.position,
      ])!,
    );
  }

  /// The dots of the side shown, along the road.
  List<_Stop> get _shown => switch (side) {
    Sides.both => _stops,
    Sides.odd => [..._stops.where((stop) => stop.isOdd)],
    Sides.even => [..._stops.where((stop) => !stop.isOdd)],
  };

  /// Whether each side is shown: the odd one (true), the even one (false).
  List<bool> get _sidesShown => switch (side) {
    Sides.both => const [true, false],
    Sides.odd => const [true],
    Sides.even => const [false],
  };

  /// This choice with [sideFor] of each side shown, the marks where the new
  /// part puts them.
  StreetPartChoice _withSidesShown(SidePart Function(bool isOdd) sideFor) {
    final shown = _sidesShown;
    return _with(
      part: _part(
        odd: shown.contains(true) ? sideFor(true) : part.odd,
        even: shown.contains(false) ? sideFor(false) : part.even,
      ),
    );
  }

  StreetPartChoice _with({StreetPart? part, Sides? side}) => StreetPartChoice._(
    _track,
    _stops,
    numbers: numbers,
    road: road,
    part: part ?? this.part,
    side: side ?? this.side,
    first: first,
    last: last,
  )._marked();

  /// This choice with its marks around the dots of the side shown that the
  /// part keeps: from the first to the last; together at the start when it
  /// keeps none.
  StreetPartChoice _marked() {
    final shown = _shown;
    var newFirst = -1;
    var newLast = 0;
    for (final (index, stop) in shown.indexed) {
      if (_sideOf(part, isOdd: stop.isOdd).holdsNumber(stop.value)) {
        if (newFirst < 0) newFirst = index;
        newLast = index + 1;
      }
    }
    return StreetPartChoice._(
      _track,
      _stops,
      numbers: numbers,
      road: road,
      part: part,
      side: side,
      first: math.max(newFirst, 0),
      last: newLast,
    );
  }

  /// What of the odd side ([isOdd]) or the even side the marks keep, the
  /// dots of that side among [kept] being between them.
  SidePart _sideKeeping(List<_Stop> kept, {required bool isOdd}) {
    final values = [
      for (final stop in kept)
        if (stop.isOdd == isOdd) stop.value,
    ];
    if (values.isEmpty) return SidePart.none;
    final dotted = [
      for (final stop in _stops)
        if (stop.isOdd == isOdd) stop.value,
    ];
    final keepsLowest = values.contains(dotted.reduce(math.min));
    final keepsHighest = values.contains(dotted.reduce(math.max));
    if (keepsLowest && keepsHighest) return SidePart.all;
    final all = _valuesOf(isOdd: isOdd);
    return _range(
      keepsLowest ? all.reduce(math.min) : values.reduce(math.min),
      keepsHighest ? all.reduce(math.max) : values.reduce(math.max),
    );
  }

  /// « Du n° [from] au n° [to] » on the odd side ([isOdd]) or the even one.
  SidePart _bounded(int? from, int? to, {required bool isOdd}) {
    if (from == null && to == null) return SidePart.all;
    final values = _valuesOf(isOdd: isOdd);
    final low = math.min(
      from ?? (values.isEmpty ? 0 : values.reduce(math.min)),
      HouseNumber.maxNumber,
    );
    final high = math.min(
      to ?? (values.isEmpty ? HouseNumber.maxNumber : values.reduce(math.max)),
      HouseNumber.maxNumber,
    );
    // The first number of the side from `low`, the last up to `high`.
    final start = low.isOdd == isOdd ? low : low + 1;
    final end = high.isOdd == isOdd ? high : high - 1;
    return start > end ? SidePart.none : _range(start, end);
  }

  /// The integer parts of the numbers of the odd side ([isOdd]) or the
  /// even one.
  List<int> _valuesOf({required bool isOdd}) => [
    for (final number in numbers)
      if (number.number.isOdd == isOdd) number.number.number,
  ];

  /// How far along the road the [gap]-th place of the marks is: half way
  /// between two dots, or a little beyond the first or the last.
  double _alongOf(int gap) {
    final shown = _shown;
    if (gap == 0) return shown.first.along - _endMetres;
    if (gap == shown.length) return shown.last.along + _endMetres;
    return (shown[gap - 1].along + shown[gap].along) / 2;
  }

  /// The numbers around the [gap]-th place of the marks.
  MarkPlace _placeOf(int gap) {
    final shown = _shown;
    if (gap == 0) return MarkBefore(shown.first.value);
    if (gap == shown.length) return MarkAfter(shown.last.value);
    return MarkBetween(shown[gap - 1].value, shown[gap].value);
  }

  PartDotLook _lookOf(PartNumber number) {
    final isOdd = number.number.isOdd;
    if (!_sidesShown.contains(isOdd)) return PartDotLook.otherSide;
    return part.holds(number.number) ? PartDotLook.kept : PartDotLook.leftOut;
  }

  /// The line the marks slide along: the [road], or the straight line
  /// between the two dots of [numbers] farthest apart; null when there is
  /// neither.
  static LineTrack? _trackFor(StreetShape road, List<PartNumber> numbers) {
    if (!road.isEmpty) return LineTrack.through(road.lines);
    final places = {for (final number in numbers) ?number.position}.toList();
    (GeoPoint, GeoPoint)? farthest;
    var longest = 0.0;
    for (var i = 0; i < places.length; i++) {
      for (var j = i + 1; j < places.length; j++) {
        final metres = metresBetween(places[i], places[j]);
        if (metres > longest) {
          longest = metres;
          farthest = (places[i], places[j]);
        }
      }
    }
    return switch (farthest) {
      (final start, final end) => LineTrack.straight(start, end),
      null => null,
    };
  }

  /// One stop per number of a side with a dot (3 and 3bis together), along
  /// [track].
  static List<_Stop> _stopsAlong(LineTrack track, List<PartNumber> numbers) {
    final alongs = <(bool, int), List<double>>{};
    for (final number in numbers) {
      if (number.position case final position?) {
        alongs
            .putIfAbsent((number.number.isOdd, number.number.number), () => [])
            .add(track.alongOf(position));
      }
    }
    final stops = [
      for (final MapEntry(key: (isOdd, value), value: places) in alongs.entries)
        (
          isOdd: isOdd,
          value: value,
          along: places.reduce((a, b) => a + b) / places.length,
        ),
    ];
    return stops..sort((a, b) {
      final byPlace = a.along.compareTo(b.along);
      return byPlace != 0 ? byPlace : a.value.compareTo(b.value);
    });
  }

  static SidePart _sideOf(StreetPart part, {required bool isOdd}) =>
      isOdd ? part.odd : part.even;

  /// A range whose bounds are on their side by construction: it cannot be
  /// refused.
  static SidePart _range(int from, int to) =>
      (SidePart.range(from, to) as Ok<SidePart, StreetPartFailure>).value;

  /// A part whose ranges were made by [_range] on their own side: it
  /// cannot be refused.
  static StreetPart _part({required SidePart odd, required SidePart even}) =>
      (StreetPart.create(
        odd: odd,
        even: even,
      ) as Ok<StreetPart, StreetPartFailure>).value;
}

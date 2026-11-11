// An in-memory StreetPartIndex: records what the open secteur says it
// holds, and answers what the other secteurs hold from what a test put in
// [others].
import 'dart:async';

import 'package:tournee_calendriers/application/ports/street_part_index.dart';
import 'package:tournee_calendriers/domain/street/sector_part.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';

/// What the open secteur told the index, in order.
sealed class IndexWrite {
  const IndexWrite(this.street);

  final BanStreetId street;
}

/// [StreetPartIndex.hold] of [part].
final class Held extends IndexWrite {
  const Held(super.street, this.part);

  final StreetPart part;

  @override
  bool operator ==(Object other) =>
      other is Held && other.street == street && other.part == part;

  @override
  int get hashCode => Object.hash(street, part);

  @override
  String toString() => 'Held(${street.value}, $part)';
}

/// [StreetPartIndex.release].
final class Released extends IndexWrite {
  const Released(super.street);

  @override
  bool operator ==(Object other) => other is Released && other.street == street;

  @override
  int get hashCode => street.hashCode;

  @override
  String toString() => 'Released(${street.value})';
}

final class FakeStreetPartIndex implements StreetPartIndex {
  FakeStreetPartIndex([Map<BanStreetId, List<SectorPart>>? others])
    : others = others ?? {};

  /// What the other secteurs hold, by street: what [othersOf] answers.
  final Map<BanStreetId, List<SectorPart>> others;

  /// Every hold and release, in order.
  final writes = <IndexWrite>[];

  /// Every street [othersOf] was asked about, in order.
  final asked = <BanStreetId>[];

  /// When set, [othersOf] waits for it before answering: a slow network.
  Completer<void>? holdReads;

  /// When set, a hold or a release is recorded at once but its `Future`
  /// ends only once this completes: a write the server has not had yet.
  Completer<void>? holdWrites;

  /// When set, a hold or a release is recorded, then fails with it: a
  /// write the server refused.
  Error? writeError;

  @override
  Future<void> hold(BanStreetId street, StreetPart part) =>
      _written(Held(street, part));

  @override
  Future<void> release(BanStreetId street) => _written(Released(street));

  Future<void> _written(IndexWrite write) async {
    writes.add(write);
    await holdWrites?.future;
    if (writeError case final error?) throw error;
  }

  @override
  Future<List<SectorPart>> othersOf(BanStreetId street) async {
    asked.add(street);
    await holdReads?.future;
    return others[street] ?? const [];
  }
}

import 'dart:async';
import 'dart:io';

import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/infrastructure/firestore/unfinished_streets.dart';

/// An in-memory [UnfinishedStreets]: the phone storage of the new streets
/// not yet all handed to Firestore (#104). [copy] gives what a restart
/// finds after a kill.
final class FakeUnfinishedStreets implements UnfinishedStreets {
  FakeUnfinishedStreets([Iterable<Street> kept = const []])
    : kept = {for (final street in kept) street.id: street};

  /// The streets kept now.
  final Map<StreetId, Street> kept;

  /// Every street ever asked to be kept, in order.
  final keptEver = <StreetId>[];

  /// Every street asked to be forgotten, in order.
  final forgotten = <StreetId>[];

  /// When set, [keep] waits for it before keeping (a slow disk).
  Completer<void>? slowDisk;

  /// When true, [keep] fails (a full disk).
  bool keepFails = false;

  /// When true, [load] fails (an unreadable folder).
  bool loadFails = false;

  /// The storage a restart finds: the streets kept at this moment.
  FakeUnfinishedStreets copy() => FakeUnfinishedStreets(kept.values);

  @override
  Future<List<Street>> load() async {
    if (loadFails) throw const FileSystemException('unreadable');
    return kept.values.toList();
  }

  @override
  Future<void> keep(Street street) async {
    keptEver.add(street.id);
    await slowDisk?.future;
    if (keepFails) throw const FileSystemException('disk full');
    kept[street.id] = street;
  }

  @override
  Future<void> forget(StreetId id) async {
    forgotten.add(id);
    kept.remove(id);
  }
}

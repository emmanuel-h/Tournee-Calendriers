// An in-memory MySectorsStore: no file, answers at once, and records every
// save so tests can assert it.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/my_sectors_store.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';

final class FakeMySectorsStore implements MySectorsStore {
  /// A phone that already knows [mySectors] (none by default).
  FakeMySectorsStore([this.mySectors = MySectors.none]);

  @override
  MySectors mySectors;

  /// Every list given to [save], in order.
  final saves = <MySectors>[];

  // `sync: true`: a listener hears a save before `save` returns, as the
  // real adapter's listeners do on the same turn of the event loop.
  final _changes = StreamController<MySectors>.broadcast(sync: true);

  @override
  Stream<MySectors> get changes => _changes.stream;

  @override
  Future<void> save(MySectors mySectors) async {
    saves.add(mySectors);
    this.mySectors = mySectors;
    _changes.add(mySectors);
  }
}

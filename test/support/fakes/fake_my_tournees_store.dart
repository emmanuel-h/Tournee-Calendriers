// An in-memory MyTourneesStore: no file, answers at once, and records every
// save so tests can assert it.
import 'dart:async';

import 'package:tournee_calendriers/application/ports/my_tournees_store.dart';
import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';

final class FakeMyTourneesStore implements MyTourneesStore {
  /// A phone that already knows [myTournees] (none by default).
  FakeMyTourneesStore([this.myTournees = MyTournees.none]);

  @override
  MyTournees myTournees;

  /// Every list given to [save], in order.
  final saves = <MyTournees>[];

  // `sync: true`: a listener hears a save before `save` returns, as the
  // real adapter's listeners do on the same turn of the event loop.
  final _changes = StreamController<MyTournees>.broadcast(sync: true);

  @override
  Stream<MyTournees> get changes => _changes.stream;

  @override
  Future<void> save(MyTournees myTournees) async {
    saves.add(myTournees);
    this.myTournees = myTournees;
    _changes.add(myTournees);
  }
}

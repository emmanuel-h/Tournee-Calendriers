import 'package:tournee_calendriers/domain/tournee/my_tournees.dart';

/// Where the phone keeps « Mes tournées » and which one is open (PLAN
/// §6.3): on the phone only, so the app reopens the last tournée at launch
/// without the network, cold start included (PLAN §7).
///
/// An application port: the use cases own it, an adapter of
/// `infrastructure/local_storage/` implements it, tests use a fake.
///
/// Read without waiting: the adapter loads the list before the first screen
/// (the composition root does it at start-up), so the title « Tournée 49 ·
/// 2026 » shows from the first frame.
abstract interface class MyTourneesStore {
  /// The member's tournées as last saved; [MyTournees.none] on a first
  /// launch.
  MyTournees get myTournees;

  /// Each list saved from now on, so every screen follows a switch made
  /// elsewhere (the sheet, a join accepted). Nothing is given on listening:
  /// read [myTournees] for the list now.
  Stream<MyTournees> get changes;

  /// Keeps [myTournees]. [myTournees] and [changes] give the new list at
  /// once; the returned `Future` ends once it is kept on the phone.
  Future<void> save(MyTournees myTournees);
}

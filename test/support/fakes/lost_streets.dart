// A StreetRepository that shows a street but has lost it when a use case
// loads it: the street went between the read and the tap.
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

import 'fake_street_repository.dart';

final class LostStreets implements StreetRepository {
  LostStreets(this.inner);

  final FakeStreetRepository inner;

  @override
  Stream<Street?> watch(StreetId id) => inner.watch(id);

  @override
  Future<Street?> find(StreetId id) async => null;

  // Any other call is a test bug: it fails, naming the call.
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

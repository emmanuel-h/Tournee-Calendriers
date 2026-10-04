// An in-memory StreetViewPreferences: no file, answers at once, and records
// every write so tests can assert it.
import 'package:tournee_calendriers/application/ports/street_view_preferences.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

final class FakeStreetViewPreferences implements StreetViewPreferences {
  /// Preferences where the streets [hidingDone] already hide their done
  /// houses.
  FakeStreetViewPreferences([Iterable<StreetId> hidingDone = const []])
    : _hidingDone = {...hidingDone};

  final Set<StreetId> _hidingDone;

  /// Every (street, hide) given to [setHidesDone], in order.
  final writes = <(StreetId, bool)>[];

  @override
  bool hidesDone(StreetId id) => _hidingDone.contains(id);

  @override
  Future<void> setHidesDone(StreetId id, {required bool hide}) async {
    writes.add((id, hide));
    hide ? _hidingDone.add(id) : _hidingDone.remove(id);
  }
}

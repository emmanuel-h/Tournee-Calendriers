import 'package:test/test.dart';
import 'package:tournee_calendriers/application/use_cases/hide_done.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

import '../../support/fakes/fake_street_view_preferences.dart';

void main() {
  final nationale = StreetId('nationale');
  final morin = StreetId('morin');

  group('ReadHideDone', () {
    test('should hide the done houses when the street was set to', () {
      final read = ReadHideDone(FakeStreetViewPreferences([nationale]));

      expect(read(nationale), isTrue);
    });

    test('should show every house when the street was never set', () {
      final read = ReadHideDone(FakeStreetViewPreferences([nationale]));

      expect(read(morin), isFalse);
    });
  });

  group('SaveHideDone', () {
    test('should remember the choice for that street only', () async {
      final preferences = FakeStreetViewPreferences();

      await SaveHideDone(preferences)(nationale, hide: true);

      expect(preferences.writes, [(nationale, true)]);
      expect(preferences.hidesDone(nationale), isTrue);
      expect(preferences.hidesDone(morin), isFalse);
    });

    test(
      'should forget the choice when the done houses are shown again',
      () async {
        final preferences = FakeStreetViewPreferences([nationale]);

        await SaveHideDone(preferences)(nationale, hide: false);

        expect(preferences.writes, [(nationale, false)]);
        expect(preferences.hidesDone(nationale), isFalse);
      },
    );
  });
}

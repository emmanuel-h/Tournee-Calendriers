import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/application/use_cases/phone_settings.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/results.dart';

void main() {
  group('ReadPhoneSettings', () {
    test('should give the name and the theme kept on the phone', () {
      final settings = ReadPhoneSettings(
        FakePhoneSettings(memberName: nameOf('Manu'), theme: ThemeChoice.dark),
      )();

      expect(settings.name, nameOf('Manu'));
      expect(settings.theme, ThemeChoice.dark);
    });
  });

  group('ChangeMemberName', () {
    test('should keep the name once cleaned', () async {
      final settings = FakePhoneSettings();

      final changed = await ChangeMemberName(settings)('  Jean   Paul ');

      expect(valueOf(changed).text, 'Jean Paul');
      expect(settings.names, [nameOf('Jean Paul')]);
    });

    test('should refuse and keep nothing when the name is blank', () async {
      final settings = FakePhoneSettings(memberName: nameOf('Manu'));

      final changed = await ChangeMemberName(settings)('   ');

      expect(failureOf(changed), MemberNameFailure.blank);
      expect(settings.names, isEmpty);
      expect(settings.memberName, nameOf('Manu'));
    });

    test('should refuse and keep nothing when the name is too long', () async {
      final settings = FakePhoneSettings();

      final changed = await ChangeMemberName(settings)('a' * 31);

      expect(failureOf(changed), MemberNameFailure.tooLong);
      expect(settings.names, isEmpty);
    });
  });

  group('ChooseTheme', () {
    test('should keep the theme chosen', () async {
      final settings = FakePhoneSettings();

      await ChooseTheme(settings)(ThemeChoice.light);

      expect(settings.themes, [ThemeChoice.light]);
    });
  });
}

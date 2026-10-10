import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_phone_settings.dart';

void main() {
  late FakePhoneSettings settings;

  ProviderContainer containerWith(FakePhoneSettings phone) {
    settings = phone;
    final container = ProviderContainer(
      overrides: [phoneSettingsProvider.overrideWithValue(phone)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('should show the name and the theme kept on the phone', () {
    final container = containerWith(
      FakePhoneSettings(memberName: nameOf('Manu'), theme: ThemeChoice.dark),
    );

    final state = container.read(settingsProvider);

    expect(state.name, 'Manu');
    expect(state.theme, AppTheme.dark);
  });

  test('should show no name before the member gives one', () {
    final container = containerWith(FakePhoneSettings());

    expect(container.read(settingsProvider).name, isNull);
    expect(container.read(settingsProvider).theme, AppTheme.system);
  });

  group('rename', () {
    test('should show and keep the cleaned name', () async {
      final container = containerWith(
        FakePhoneSettings(memberName: nameOf('Manu'), theme: ThemeChoice.dark),
      );

      final refusal = await container
          .read(settingsProvider.notifier)
          .rename(' Emmanuel ');

      expect(refusal, isNull);
      expect(container.read(settingsProvider).name, 'Emmanuel');
      expect(container.read(settingsProvider).theme, AppTheme.dark);
      expect(settings.names, [nameOf('Emmanuel')]);
    });

    test(
      'should say why and keep the old name when the name is refused',
      () async {
        final container = containerWith(
          FakePhoneSettings(memberName: nameOf('Manu')),
        );

        final refusal = await container
            .read(settingsProvider.notifier)
            .rename('  ');

        expect(refusal, MemberNameFailure.blank);
        expect(container.read(settingsProvider).name, 'Manu');
        expect(settings.names, isEmpty);
      },
    );
  });

  test('should show each theme kept on the phone', () {
    for (final (kept, shown) in [
      (ThemeChoice.system, AppTheme.system),
      (ThemeChoice.light, AppTheme.light),
      (ThemeChoice.dark, AppTheme.dark),
    ]) {
      final container = containerWith(FakePhoneSettings(theme: kept));

      expect(container.read(settingsProvider).theme, shown, reason: '$kept');
    }
  });

  group('chooseTheme', () {
    test('should show the theme at once and keep it', () async {
      final container = containerWith(
        FakePhoneSettings(memberName: nameOf('Manu')),
      );

      final saving = container
          .read(settingsProvider.notifier)
          .chooseTheme(AppTheme.light);
      expect(container.read(settingsProvider).theme, AppTheme.light);
      await saving;

      expect(container.read(settingsProvider).name, 'Manu');
      expect(settings.themes, [ThemeChoice.light]);
    });

    test('should keep each theme under its own choice', () async {
      final container = containerWith(FakePhoneSettings());
      final notifier = container.read(settingsProvider.notifier);

      await notifier.chooseTheme(AppTheme.dark);
      await notifier.chooseTheme(AppTheme.system);
      await notifier.chooseTheme(AppTheme.light);

      expect(settings.themes, [
        ThemeChoice.dark,
        ThemeChoice.system,
        ThemeChoice.light,
      ]);
    });
  });

  group('SettingsState', () {
    test('should be equal when the name and the theme are', () {
      const state = SettingsState(name: 'Manu', theme: AppTheme.dark);

      expect(state, const SettingsState(name: 'Manu', theme: AppTheme.dark));
      expect(
        state.hashCode,
        const SettingsState(name: 'Manu', theme: AppTheme.dark).hashCode,
      );
      expect(
        state == const SettingsState(name: 'Léa', theme: AppTheme.dark),
        isFalse,
      );
      expect(
        state == const SettingsState(name: 'Manu', theme: AppTheme.light),
        isFalse,
      );
    });
  });
}

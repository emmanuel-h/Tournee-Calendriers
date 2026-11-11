import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/welcome/welcome_notifier.dart';
import 'package:tournee_calendriers/presentation/welcome/welcome_state.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';

void main() {
  late FakePhoneSettings settings;
  late ProviderContainer container;

  /// Opens « Bienvenue » on a phone whose name is [name] and that knows no
  /// tournée yet.
  void open({MemberName? name}) {
    settings = FakePhoneSettings(memberName: name);
    container = ProviderContainer(
      overrides: [
        phoneSettingsProvider.overrideWithValue(settings),
        sectorRepositoryProvider.overrideWithValue(FakeSectorRepository()),
        identityProvider.overrideWithValue(FakeIdentity(manuId)),
        mySectorsStoreProvider.overrideWithValue(FakeMySectorsStore()),
      ],
    );
    addTearDown(container.dispose);
    container.listen(welcomeProvider, (_, _) {});
  }

  WelcomeState state() => container.read(welcomeProvider);
  WelcomeNotifier notifier() => container.read(welcomeProvider.notifier);

  test('should start empty and closed on a phone without a name', () {
    open();

    expect(
      state(),
      const WelcomeState(name: '', canGoOn: false, tooLong: false),
    );
  });

  test('should start from the name kept and let it go on', () {
    open(name: nameOf('Manu'));

    expect(
      state(),
      const WelcomeState(name: 'Manu', canGoOn: true, tooLong: false),
    );
  });

  test('should let a name go on once typed', () {
    open();

    notifier().type('Léa');

    expect(
      state(),
      const WelcomeState(name: 'Léa', canGoOn: true, tooLong: false),
    );
  });

  test('should keep the buttons closed when only spaces are typed', () {
    open();

    notifier().type('   ');

    expect(state().canGoOn, isFalse);
    expect(state().tooLong, isFalse);
  });

  test('should let a name of 30 characters go on', () {
    open();

    notifier().type('A' * MemberName.maxLength);

    expect(state().canGoOn, isTrue);
    expect(state().tooLong, isFalse);
  });

  test('should say a name of 31 characters is too long', () {
    open();

    notifier().type('A' * (MemberName.maxLength + 1));

    expect(state().canGoOn, isFalse);
    expect(state().tooLong, isTrue);
  });

  test('should keep the name, cleaned, when it goes on', () async {
    open();
    notifier().type('  Léa  ');

    expect(await notifier().confirm(), isTrue);

    expect(settings.names, [nameOf('Léa')]);
    expect(container.read(settingsProvider).name, 'Léa');
  });

  group('on a phone already in a secteur', () {
    late FakeSectorRepository sectors;

    /// « Bienvenue » with no name kept, Manu in the 49 (a phone of before
    /// the names, say).
    void openIn49() {
      settings = FakePhoneSettings();
      sectors = FakeSectorRepository([team()]);
      container = ProviderContainer(
        overrides: [
          phoneSettingsProvider.overrideWithValue(settings),
          sectorRepositoryProvider.overrideWithValue(sectors),
          identityProvider.overrideWithValue(FakeIdentity(manuId)),
          mySectorsStoreProvider.overrideWithValue(
            FakeMySectorsStore(MySectors.none.remember(sector49)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(welcomeProvider, (_, _) {});
    }

    test('should go on with the name kept, even where a secteur keeps '
        'another one', () async {
      openIn49();
      notifier().type('Léa');

      expect(await notifier().confirm(), isTrue);

      expect(settings.names, [nameOf('Léa')]);
    });

    test('should not go on when no secteur can be reached', () async {
      openIn49();
      sectors.offline = true;
      notifier().type('Emmanuel');

      expect(await notifier().confirm(), isFalse);

      expect(settings.names, isEmpty);
    });
  });

  test('should keep nothing when the name is not valid', () async {
    open();
    notifier().type(' ');

    expect(await notifier().confirm(), isFalse);

    expect(settings.names, isEmpty);
  });

  test('should equal a state with the same values only', () {
    const state = WelcomeState(name: 'Léa', canGoOn: true, tooLong: false);

    expect(
      state,
      const WelcomeState(name: 'Léa', canGoOn: true, tooLong: false),
    );
    expect(
      state.hashCode,
      const WelcomeState(name: 'Léa', canGoOn: true, tooLong: false).hashCode,
    );
    expect(
      state,
      isNot(const WelcomeState(name: 'Lea', canGoOn: true, tooLong: false)),
    );
    expect(
      state,
      isNot(const WelcomeState(name: 'Léa', canGoOn: false, tooLong: false)),
    );
    expect(
      state,
      isNot(const WelcomeState(name: 'Léa', canGoOn: true, tooLong: true)),
    );
    expect(state.toString(), 'WelcomeState(Léa, true, false)');
  });
}

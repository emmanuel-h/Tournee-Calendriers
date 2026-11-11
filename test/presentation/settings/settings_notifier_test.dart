import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/phone_settings.dart';
import 'package:tournee_calendriers/domain/sector/member.dart';
import 'package:tournee_calendriers/domain/sector/member_name.dart';
import 'package:tournee_calendriers/domain/sector/my_sectors.dart';
import 'package:tournee_calendriers/domain/sector/sector_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_state.dart';

import '../../domain/sector/my_sectors_fixtures.dart';
import '../../domain/sector/sector_fixtures.dart';
import '../../support/fakes/fake_my_sectors_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_sector_repository.dart';

void main() {
  late FakePhoneSettings settings;
  late FakeSectorRepository sectors;
  late FakeMySectorsStore store;

  setUp(() => store = FakeMySectorsStore(MySectors.none.remember(sector49)));

  /// Manu's phone, which knows the 49 he created.
  ProviderContainer containerWith(FakePhoneSettings phone) {
    settings = phone;
    sectors = FakeSectorRepository([team()]);
    final container = ProviderContainer(
      overrides: [
        phoneSettingsProvider.overrideWithValue(phone),
        sectorRepositoryProvider.overrideWithValue(sectors),
        identityProvider.overrideWithValue(FakeIdentity(manuId)),
        mySectorsStoreProvider.overrideWithValue(store),
      ],
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

      final outcome = await container
          .read(settingsProvider.notifier)
          .rename(' Emmanuel ');

      expect(outcome, const NameSaved());
      expect(container.read(settingsProvider).name, 'Emmanuel');
      expect(container.read(settingsProvider).theme, AppTheme.dark);
      expect(settings.names, [nameOf('Emmanuel')]);
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Emmanuel'));
    });

    test(
      'should say why and keep the old name when the name is refused',
      () async {
        final container = containerWith(
          FakePhoneSettings(memberName: nameOf('Manu')),
        );

        final outcome = await container
            .read(settingsProvider.notifier)
            .rename('  ');

        expect(outcome, const NameNotValid(MemberNameFailure.blank));
        expect(container.read(settingsProvider).name, 'Manu');
        expect(settings.names, isEmpty);
      },
    );

    test('should say offline and keep the old name when no secteur can be '
        'reached', () async {
      final container = containerWith(
        FakePhoneSettings(memberName: nameOf('Manu')),
      );
      sectors.offline = true;

      final outcome = await container
          .read(settingsProvider.notifier)
          .rename('Emmanuel');

      expect(outcome, isA<NameOffline>());
      expect(container.read(settingsProvider).name, 'Manu');
    });

    test('should say where the old name is kept, the new one shown', () async {
      final container = containerWith(
        FakePhoneSettings(memberName: nameOf('Manu')),
      );
      sectors.takenNames.add((sectorId, 'emmanuel'));

      final outcome = await container
          .read(settingsProvider.notifier)
          .rename('Emmanuel');

      expect(
        outcome,
        NameKeptIn([
          SectorNameLine(
            id: sectorId,
            number: 49,
            centre: 'CS Villefranche',
            name: 'Manu',
          ),
        ]),
      );
      final state = container.read(settingsProvider);
      expect(state.name, 'Emmanuel');
      expect(state.sectorNames.single.name, 'Manu');
      expect(state.showsSectorNames, isTrue);
    });
  });

  group('renameIn', () {
    late ProviderContainer container;

    setUp(() {
      container = containerWith(FakePhoneSettings(memberName: nameOf('Manu')));
    });

    test('should give the member the name in that secteur only', () async {
      final outcome = await container
          .read(settingsProvider.notifier)
          .renameIn(sectorId, 'Manu D.');

      expect(outcome, const NameSaved());
      expect(sectors[sectorId]!.memberOf(manuId)!.name, nameOf('Manu D.'));
      expect(container.read(settingsProvider).name, 'Manu');
      expect(
        container.read(settingsProvider).sectorNames.single.name,
        'Manu D.',
      );
    });

    test('should say each reason it was not given', () async {
      final notifier = container.read(settingsProvider.notifier);

      expect(
        await notifier.renameIn(sectorId, ''),
        const NameNotValid(MemberNameFailure.blank),
      );
      expect(
        await notifier.renameIn(SectorId('t99'), 'Manu D.'),
        isA<NameSectorGone>(),
      );
      sectors.takenNames.add((sectorId, 'manu d'));
      expect(
        await notifier.renameIn(sectorId, 'Manu D.'),
        isA<NameTakenThere>(),
      );
      sectors.offline = true;
      expect(await notifier.renameIn(sectorId, 'Manu B.'), isA<NameOffline>());
    });
  });

  group('names per secteur', () {
    test('should list each secteur with the name the member goes by there, '
        'visits left out', () {
      store = FakeMySectorsStore(
        MySectors.none
            .remember(sector49.withMemberName(nameOf('Manu D.')))
            .remember(sector12)
            .remember(summaryOf('t50', 50, status: MemberStatus.visiting)),
      );
      final container = containerWith(
        FakePhoneSettings(memberName: nameOf('Manu')),
      );

      final state = container.read(settingsProvider);

      expect(state.sectorNames, [
        SectorNameLine(
          id: sectorId,
          number: 49,
          centre: 'CS Villefranche',
          name: 'Manu D.',
        ),
        SectorNameLine(
          id: SectorId('t12'),
          number: 12,
          centre: 'CS Villefranche',
          name: 'Manu',
        ),
      ]);
      expect(state.showsSectorNames, isTrue);
    });

    test('should show no list when every secteur knows the prénom', () {
      final container = containerWith(
        FakePhoneSettings(memberName: nameOf('Manu')),
      );

      expect(container.read(settingsProvider).sectorNames.single.name, 'Manu');
      expect(container.read(settingsProvider).showsSectorNames, isFalse);
    });

    test('should follow « Mes secteurs » as it changes', () async {
      final container = containerWith(
        FakePhoneSettings(memberName: nameOf('Manu')),
      );
      container.listen(settingsProvider, (_, _) {});

      await store.save(
        MySectors.none.remember(sector49.withMemberName(nameOf('Manu D.'))),
      );

      expect(
        container.read(settingsProvider).sectorNames.single.name,
        'Manu D.',
      );
    });

    test('should be equal when every field is', () {
      SectorNameLine line({String? name = 'Manu'}) => SectorNameLine(
        id: sectorId,
        number: 49,
        centre: 'CS Villefranche',
        name: name,
      );

      expect(line(), line());
      expect(line().hashCode, line().hashCode);
      expect(line() == line(name: 'Manu D.'), isFalse);
      expect(line().toString(), 'SectorNameLine(t49, 49, Manu)');
      expect(
        SettingsState(
          name: 'Manu',
          theme: AppTheme.dark,
          sectorNames: [line()],
        ),
        SettingsState(
          name: 'Manu',
          theme: AppTheme.dark,
          sectorNames: [line()],
        ),
      );
      expect(
        SettingsState(
          name: 'Manu',
          theme: AppTheme.dark,
          sectorNames: [line()],
        ).hashCode,
        SettingsState(
          name: 'Manu',
          theme: AppTheme.dark,
          sectorNames: [line()],
        ).hashCode,
      );
      expect(
        const SettingsState(name: 'Manu', theme: AppTheme.dark) ==
            SettingsState(
              name: 'Manu',
              theme: AppTheme.dark,
              sectorNames: [line()],
            ),
        isFalse,
      );
      expect(
        const NameNotValid(MemberNameFailure.blank).hashCode,
        const NameNotValid(MemberNameFailure.blank).hashCode,
      );
      expect(NameKeptIn([line()]).hashCode, NameKeptIn([line()]).hashCode);
    });
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

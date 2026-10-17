import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/tournee/campaign_year.dart';
import 'package:tournee_calendriers/domain/tournee/member_name.dart';
import 'package:tournee_calendriers/domain/tournee/rescue_centre.dart';
import 'package:tournee_calendriers/domain/tournee/tournee.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_number.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_repository.dart';
import 'package:tournee_calendriers/presentation/account/account_notifier.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/presentation/new_tournee/new_tournee_notifier.dart';
import 'package:tournee_calendriers/presentation/new_tournee/new_tournee_state.dart';

import '../../domain/tournee/tournee_fixtures.dart';
import '../../support/fakes/fake_member_account.dart';
import '../../support/fakes/fake_my_tournees_store.dart';
import '../../support/fakes/fake_phone_settings.dart';
import '../../support/fakes/fake_ports.dart';
import '../../support/fakes/fake_tournee_directory.dart';
import '../../support/fakes/fake_tournee_repository.dart';
import '../../support/results.dart';
import '../../support/scripted_random.dart';

/// Lets every pending future and zero-length timer run.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

RescueCentre _centre(String name) => valueOf(RescueCentre.create(name));

/// Villefranche-sur-Saône as the commune search suggests it.
final villefrancheOption = CommuneOption.of(
  CommuneMatch(
    commune: villefrancheCommune.commune,
    postcodes: const ['69400'],
    centre: villefrancheCommune.centre,
  ),
);

/// Gleizé as the commune search suggests it.
final gleizeOption = CommuneOption.of(
  CommuneMatch(
    commune: gleizeCommune.commune,
    postcodes: const ['69400'],
    centre: gleizeCommune.centre,
  ),
);

void main() {
  final csAnse = _centre('CS Anse');
  final csVillefrancheSurSaone = _centre('CS Villefranche-sur-Saône');
  final number12 = valueOf(TourneeNumber.create(12));
  final now = DateTime.utc(2026, 11, 2, 14);

  late FakeMemberAccount account;
  late FakeTourneeDirectory directory;
  late FakeTourneeRepository tournees;
  late FakeMyTourneesStore store;
  late ProviderContainer container;

  /// Opens « Nouvelle tournée » on Manu's phone; [name] is the name kept.
  Future<void> open({MemberName? name}) async {
    container = ProviderContainer(
      overrides: [
        memberAccountProvider.overrideWithValue(account),
        tourneeDirectoryProvider.overrideWithValue(directory),
        tourneeRepositoryProvider.overrideWithValue(tournees),
        myTourneesStoreProvider.overrideWithValue(store),
        phoneSettingsProvider.overrideWithValue(
          FakePhoneSettings(memberName: name),
        ),
        clockProvider.overrideWithValue(FakeClock(now)),
        idGeneratorProvider.overrideWithValue(FakeIdGenerator('tournee')),
        // The indexes of `2`…`7` in the alphabet: the code `234567`.
        randomProvider.overrideWithValue(
          ScriptedRandom([23, 24, 25, 26, 27, 28]),
        ),
        duplicateCheckDelayProvider.overrideWithValue(Duration.zero),
      ],
    );
    addTearDown(container.dispose);
    // `listen` keeps the auto-disposed provider alive, as the screen does.
    container.listen(newTourneeProvider, (_, _) {});
    await _settle();
  }

  NewTourneeState state() => container.read(newTourneeProvider);
  NewTourneeNotifier form() => container.read(newTourneeProvider.notifier);

  /// Picks the CS Villefranche, Villefranche-sur-Saône and types 49.
  Future<void> fill() async {
    form().chooseCentre(csVillefranche);
    form().addCommune(villefrancheOption);
    form().typeNumber('49');
    await _settle();
  }

  setUp(() {
    account = FakeMemberAccount(signedInMember: manuId);
    directory = FakeTourneeDirectory()
      ..centres = [csAnse, csVillefranche, csVillefrancheSurSaone];
    tournees = FakeTourneeRepository();
    store = FakeMyTourneesStore();
  });

  group('when the screen opens', () {
    test('should pre-fill the year and list the known centres', () async {
      await open(name: nameOf('Manu'));

      expect(state().initialYear, '2026');
      expect(state().year, valueOf(CampaignYear.create(2026)));
      expect(state().yearInvalid, isFalse);
      expect(state().signedIn, isTrue);
      expect(state().hasName, isTrue);
      expect(state().centreQuery, '');
      expect(state().centre, isNull);
      expect(state().number, isNull);
      expect(
        state().known,
        CentresLoaded([csAnse, csVillefranche, csVillefrancheSurSaone]),
      );
      expect(state().duplicate, DuplicateCheck.unknown);
      expect(state().run, isA<CreateIdle>());
      expect(directory.centresAsked, 1);
    });

    test('should say the phone has no name when none is kept', () async {
      await open();

      expect(state().hasName, isFalse);
    });

    test(
      'should offer only a new centre when the server cannot be reached',
      () async {
        directory.offline = true;

        await open(name: nameOf('Manu'));
        form().typeCentre('villef');

        expect(state().known, const CentresUnavailable());
        expect(state().suggestions, isEmpty);
        expect(state().newCentre, _centre('villef'));
      },
    );

    test('should wait 300 ms after the typing by default', () {
      final defaults = ProviderContainer();
      addTearDown(defaults.dispose);

      expect(
        defaults.read(duplicateCheckDelayProvider),
        const Duration(milliseconds: 300),
      );
    });

    test(
      'should ask the server nothing while the phone has no account',
      () async {
        account = FakeMemberAccount()..gate = Completer<void>();

        await open(name: nameOf('Manu'));
        await fill();

        expect(state().signedIn, isFalse);
        expect(state().known, const CentresLoading());
        expect(directory.centresAsked, 0);
        expect(directory.takenAsked, isEmpty);
        expect(state().canCreate, isFalse);
      },
    );
  });

  group('first start offline, then the network back', () {
    test(
      'should create the tournée after « Réessayer », without restart',
      () async {
        // No account, and no network for the sign-in.
        account = FakeMemberAccount();
        await open(name: nameOf('Manu'));
        await fill();
        expect(state().signedIn, isFalse);
        expect(state().canCreate, isFalse);

        account.nextMember = manuId;
        await container.read(accountProvider.notifier).retry();
        await _settle();

        expect(state().signedIn, isTrue);
        expect(state().known, isA<CentresLoaded>());
        expect(directory.takenAsked, [(csVillefranche, number49)]);
        expect(state().duplicate, DuplicateCheck.free);

        await form().create();

        expect(state().run, isA<TourneeCreated>());
        expect(tournees.added.single.createdBy, manuId);
      },
    );
  });

  group('the centre de secours', () {
    setUp(() => open(name: nameOf('Manu')));

    test('should list every known centre before a station is named', () {
      form().typeCentre('CS ');

      expect(state().suggestions, [
        csAnse,
        csVillefranche,
        csVillefrancheSurSaone,
      ]);
      expect(state().newCentre, isNull);
    });

    test('should list the known centres the text names as stations', () {
      form().typeCentre('villef');

      expect(state().suggestions, [csVillefranche, csVillefrancheSurSaone]);
    });

    test('should offer to add a station no known centre is', () {
      form().typeCentre('  CS   Gleizé ');

      expect(state().suggestions, isEmpty);
      expect(state().newCentre, _centre('CS Gleizé'));
      expect(state().newCentre?.name, 'CS Gleizé');
    });

    test('should not offer to add a known station written another way', () {
      form().typeCentre('CIS Villefranche');

      expect(state().suggestions, [csVillefranche, csVillefrancheSurSaone]);
      expect(state().newCentre, isNull);
    });

    test('should offer to add a name the list only starts like', () {
      form().typeCentre('CS Villefranche Nord');

      expect(state().newCentre, _centre('CS Villefranche Nord'));
    });

    test('should take the centre picked and close the list', () {
      form().typeCentre('villef');

      form().chooseCentre(csVillefranche);

      expect(state().centre, csVillefranche);
      expect(state().centreQuery, 'CS Villefranche');
      expect(state().suggestions, isEmpty);
      expect(state().newCentre, isNull);
    });

    test('should forget the centre picked when the text changes', () {
      form().chooseCentre(csVillefranche);

      form().typeCentre('CS Villefranch');

      expect(state().centre, isNull);
      expect(state().centreQuery, 'CS Villefranch');
    });

    test('should accept a name of 80 characters', () {
      form().typeCentre('A' * RescueCentre.maxLength);

      expect(state().centreTooLong, isFalse);
      expect(state().newCentre?.name, 'A' * RescueCentre.maxLength);
    });

    test('should refuse a name of 81 characters', () {
      form().typeCentre('A' * (RescueCentre.maxLength + 1));

      expect(state().centreTooLong, isTrue);
      expect(state().suggestions, isEmpty);
      expect(state().newCentre, isNull);
    });

    test('should not say a blank name is too long', () {
      form().typeCentre('');

      expect(state().centreTooLong, isFalse);
    });
  });

  group('the communes', () {
    setUp(() => open(name: nameOf('Manu')));

    test('should start without commune, one to add', () {
      expect(state().communes, isEmpty);
      expect(state().canAddCommune, isTrue);
    });

    test('should add each commune picked after the others', () {
      form()
        ..addCommune(villefrancheOption)
        ..addCommune(gleizeOption);

      expect(state().communes, [villefrancheOption, gleizeOption]);
    });

    test('should not add a commune picked twice', () {
      form()
        ..addCommune(villefrancheOption)
        ..addCommune(villefrancheOption);

      expect(state().communes, [villefrancheOption]);
    });

    test('should remove the commune of the chip', () {
      form()
        ..addCommune(villefrancheOption)
        ..addCommune(gleizeOption)
        ..removeCommune(villefrancheOption.inseeCode);

      expect(state().communes, [gleizeOption]);
    });

    test('should add up to the most communes a tournée covers, no more', () {
      final options = [
        for (var i = 1; i <= Tournee.maxCommunes + 1; i++)
          CommuneOption(
            commune: valueOf(
              Commune.create(
                inseeCode: '69${'$i'.padLeft(3, '0')}',
                name: 'Commune $i',
              ),
            ),
            postcodes: const [],
          ),
      ];
      for (final option in options.take(Tournee.maxCommunes - 1)) {
        form().addCommune(option);
      }
      expect(state().canAddCommune, isTrue);

      form().addCommune(options[Tournee.maxCommunes - 1]);
      expect(state().canAddCommune, isFalse);
      form().addCommune(options.last);

      expect(state().communes, hasLength(Tournee.maxCommunes));
    });

    test('should add no commune once the tournée is created', () async {
      await fill();
      await form().create();

      expect(state().canAddCommune, isFalse);
      form().addCommune(gleizeOption);
      expect(state().communes, [villefrancheOption]);
    });
  });

  group('the number and the year', () {
    setUp(() => open(name: nameOf('Manu')));

    test('should take a number from 1 to 9999', () {
      form().typeNumber('1');
      expect(state().number, valueOf(TourneeNumber.create(1)));
      expect(state().numberInvalid, isFalse);

      form().typeNumber('9999');
      expect(state().number, valueOf(TourneeNumber.create(9999)));
      expect(state().numberInvalid, isFalse);
    });

    test('should say 0, 10000 and letters are no number', () {
      for (final text in ['0', '10000', '4a']) {
        form().typeNumber(text);

        expect(state().number, isNull, reason: text);
        expect(state().numberInvalid, isTrue, reason: text);
      }
    });

    test('should say nothing of a blank number', () {
      form().typeNumber('4a');

      form().typeNumber(' ');

      expect(state().number, isNull);
      expect(state().numberInvalid, isFalse);
    });

    test('should take a year from 2000 to 2099', () {
      form().typeYear('2099');
      expect(state().year, valueOf(CampaignYear.create(2099)));
      expect(state().yearInvalid, isFalse);

      form().typeYear('2000');
      expect(state().year, valueOf(CampaignYear.create(2000)));
    });

    test('should say 1999 and 2100 are no year', () {
      for (final text in ['1999', '2100']) {
        form().typeYear(text);

        expect(state().year, isNull, reason: text);
        expect(state().yearInvalid, isTrue, reason: text);
      }
    });

    test('should say nothing of a blank year, and not create', () async {
      await fill();

      form().typeYear('');

      expect(state().year, isNull);
      expect(state().yearInvalid, isFalse);
      expect(state().canCreate, isFalse);
    });
  });

  group('the duplicate check', () {
    test('should say a number free in the picked centre is free', () async {
      await open(name: nameOf('Manu'));

      await fill();

      expect(directory.takenAsked, [(csVillefranche, number49)]);
      expect(state().duplicate, DuplicateCheck.free);
      expect(state().canCreate, isTrue);
    });

    test('should say a number taken in the picked centre is taken', () async {
      directory.taken.add((csVillefranche.key, number49));
      await open(name: nameOf('Manu'));

      await fill();

      expect(state().duplicate, DuplicateCheck.taken);
      expect(state().canCreate, isFalse);
    });

    test(
      'should ask once the typing pauses, for the last number only',
      () async {
        await open(name: nameOf('Manu'));
        form().chooseCentre(csVillefranche);
        await _settle();

        form().typeNumber('4');
        form().typeNumber('49');
        await _settle();

        expect(directory.takenAsked, [(csVillefranche, number49)]);
      },
    );

    test('should ignore a late answer about an older number', () async {
      directory.taken.add((csVillefranche.key, number49));
      final first = Completer<void>();
      final second = Completer<void>();
      directory.takenGates.addAll([first, second]);
      await open(name: nameOf('Manu'));
      await fill();

      form().typeNumber('12');
      await _settle();
      second.complete();
      await _settle();
      first.complete();
      await _settle();

      expect(directory.takenAsked, [
        (csVillefranche, number49),
        (csVillefranche, number12),
      ]);
      expect(state().duplicate, DuplicateCheck.free);
    });

    test('should not know when the server cannot be reached', () async {
      await open(name: nameOf('Manu'));
      directory.offline = true;

      await fill();

      expect(state().duplicate, DuplicateCheck.unknown);
      expect(state().canCreate, isTrue);
    });

    test('should forget the answer when the centre is typed again', () async {
      directory.taken.add((csVillefranche.key, number49));
      await open(name: nameOf('Manu'));
      await fill();

      form().typeCentre('CS Ans');

      expect(state().duplicate, DuplicateCheck.unknown);
      expect(state().canCreate, isFalse);
    });

    test('should not ask without a centre picked', () async {
      await open(name: nameOf('Manu'));

      form().typeNumber('49');
      await _settle();

      expect(directory.takenAsked, isEmpty);
    });
  });

  group('« Créer »', () {
    test('should create the tournée and show its code', () async {
      await open(name: nameOf('Manu'));
      await fill();

      await form().create();

      expect(
        state().run,
        const TourneeCreated(
          number: 49,
          centre: 'CS Villefranche',
          code: '234-567',
          qrData: '234567',
        ),
      );
      expect(state().isCreated, isTrue);
      expect(state().canCreate, isFalse);
      final created = tournees.added.single;
      expect(created.centre, csVillefranche);
      expect(created.number, number49);
      expect(created.currentCampaign, campaign2026);
      expect(created.members.single.name, nameOf('Manu'));
      expect(created.communes, [villefrancheCommune]);
      expect(store.myTournees.currentId, created.id);
    });

    test('should create it in the year typed', () async {
      await open(name: nameOf('Manu'));
      await fill();
      form().typeYear('2027');

      await form().create();

      expect(
        tournees.added.single.currentCampaign,
        valueOf(CampaignYear.create(2027)),
      );
    });

    test('should be creating while the server answers', () async {
      await open(name: nameOf('Manu'));
      await fill();

      final creating = form().create();

      expect(state().run, const CreateInProgress());
      expect(state().canCreate, isFalse);
      await creating;
    });

    test('should show the number taken when it was taken meanwhile', () async {
      tournees.addFailure = AddTourneeFailure.alreadyExists;
      await open(name: nameOf('Manu'));
      await fill();

      await form().create();

      expect(state().run, const CreateIdle());
      expect(state().duplicate, DuplicateCheck.taken);
      expect(state().canCreate, isFalse);
      expect(store.saves, isEmpty);
    });

    test('should say offline and let it be tried again', () async {
      tournees.addFailure = AddTourneeFailure.noNetwork;
      await open(name: nameOf('Manu'));
      await fill();

      await form().create();

      expect(state().run, const CreateOffline());
      expect(state().canCreate, isTrue);
      expect(store.saves, isEmpty);
    });

    test('should say the phone is no longer an admin\'s and not let it be '
        'tried again', () async {
      tournees.addFailure = AddTourneeFailure.notAdmin;
      await open(name: nameOf('Manu'));
      await fill();

      await form().create();

      expect(state().run, const CreateNotAdmin());
      expect(state().canCreate, isFalse);
      expect(state().isCreated, isFalse);
      expect(store.saves, isEmpty);
    });

    test('should create nothing without a name kept', () async {
      await open();
      await fill();

      await form().create();

      expect(state().canCreate, isFalse);
      expect(tournees.added, isEmpty);
    });

    test('should create nothing without a centre picked', () async {
      await open(name: nameOf('Manu'));
      form().typeNumber('49');
      await _settle();

      await form().create();

      expect(tournees.added, isEmpty);
    });

    test('should create nothing without a commune', () async {
      await open(name: nameOf('Manu'));
      await fill();
      form().removeCommune(villefrancheOption.inseeCode);

      expect(state().canCreate, isFalse);
      await form().create();
      expect(tournees.added, isEmpty);
    });

    test('should create nothing without a number', () async {
      await open(name: nameOf('Manu'));
      form().chooseCentre(csVillefranche);
      await _settle();

      expect(state().canCreate, isFalse);
    });

    test(
      'should keep the created code when an older check answers late',
      () async {
        final late = Completer<void>();
        await open(name: nameOf('Manu'));
        directory.takenGates.add(late);
        await fill();

        await form().create();
        late.complete();
        await _settle();

        expect(state().run, isA<TourneeCreated>());
        expect(state().duplicate, DuplicateCheck.unknown);
      },
    );
  });

  group('values', () {
    test('should equal created tournées with the same values only', () {
      const created = TourneeCreated(
        number: 49,
        centre: 'CS Villefranche',
        code: 'K7P-2QX',
        qrData: 'K7P2QX',
      );

      expect(
        created,
        const TourneeCreated(
          number: 49,
          centre: 'CS Villefranche',
          code: 'K7P-2QX',
          qrData: 'K7P2QX',
        ),
      );
      expect(
        created.hashCode,
        const TourneeCreated(
          number: 49,
          centre: 'CS Villefranche',
          code: 'K7P-2QX',
          qrData: 'K7P2QX',
        ).hashCode,
      );
      expect(
        created,
        isNot(
          const TourneeCreated(
            number: 12,
            centre: 'CS Villefranche',
            code: 'K7P-2QX',
            qrData: 'K7P2QX',
          ),
        ),
      );
      expect(
        created.toString(),
        'TourneeCreated(49, CS Villefranche, K7P-2QX)',
      );
    });

    test('should equal known centres with the same centres', () {
      expect(CentresLoaded([csAnse]), CentresLoaded([csAnse]));
      expect(
        CentresLoaded([csAnse]).hashCode,
        CentresLoaded([csAnse]).hashCode,
      );
      expect(CentresLoaded([csAnse]), isNot(CentresLoaded([csVillefranche])));
    });

    test('should start with an invalid year when the clock is past 2099', () {
      final start = NewTourneeState.start(
        initialYear: '2100',
        signedIn: true,
        hasName: true,
      );

      expect(start.year, isNull);
      expect(start.yearInvalid, isTrue);
    });
  });
}

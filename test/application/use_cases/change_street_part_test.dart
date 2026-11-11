import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/address_directory.dart';
import 'package:tournee_calendriers/application/use_cases/change_street_part.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/house.dart';
import 'package:tournee_calendriers/domain/street/removed_house.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';

import '../../support/fakes/fake_address_directory.dart';
import '../../support/fakes/fake_street_repository.dart';
import '../../support/results.dart';
import '../../support/street_fixtures.dart';
import 'street_fixtures.dart';

final _lilasBan = BanStreetId('69264_0420');

/// The Rue des Lilas holds 5 (« repasser »), 7 (to do) and 8 (a building
/// with a door done): only the odd side.
final _oddSide = part(odd: SidePart.all, even: SidePart.none);

/// The numbers the BAN gives the Rue des Lilas.
StreetNumbers _banNumbers() => StreetNumbers(
  id: _lilasBan,
  name: streetName('Rue des Lilas'),
  commune: villefranche,
  numbers: [
    DirectoryNumber(number: n('5'), position: townHallDoor),
    DirectoryNumber(number: n('7')),
    DirectoryNumber(number: n('8')),
    DirectoryNumber(number: n('10'), position: northDoor),
  ],
  invalidNumbers: 0,
  duplicateNumbers: 0,
);

void main() {
  late FakeStreetRepository streets;
  late FakeAddressDirectory directory;
  late ChangeStreetPart changePart;

  void useDirectory(Result<StreetNumbers, AddressDirectoryFailure> answer) {
    directory = FakeAddressDirectory(streets: {_lilasBan: answer});
    changePart = ChangeStreetPart(
      streets,
      directory,
      clockAtTwo(),
      leaOnThePhone(),
    );
  }

  setUp(() {
    streets = repositoryWithLilas();
    useDirectory(Ok(_banNumbers()));
  });

  Street stored() => streets[lilasId]!;

  List<String> labels(Street street) => [
    for (final house in street.houses) house.number.label,
  ];

  /// The Rue des Lilas once its even side left for the Corbeille.
  Future<void> keepOnlyTheOddSide() async {
    valueOf(await changePart(lilasId, _oddSide, marksConfirmed: true));
    streets.saved.clear();
  }

  group('shrinking', () {
    test('should change nothing and name the numbers with marks that would '
        'leave', () async {
      final refusal = failureOf(await changePart(lilasId, _oddSide));

      expect(refusal, MarkedNumbersLeaving([n('8')]));
      expect((refusal as MarkedNumbersLeaving).count, 1);
      expect(streets.saved, isEmpty);
      expect(stored().part, StreetPart.whole);
    });

    test('should send the numbers left out to the Corbeille once the marks '
        'are confirmed', () async {
      final change = valueOf(
        await changePart(lilasId, _oddSide, marksConfirmed: true),
      );

      expect(change.before, StreetPart.whole);
      expect(change.part, _oddSide);
      expect(change.removed, [RemovedHouse(house: eight, removal: leaAtTwo)]);
      expect(change.restored, isEmpty);
      expect(change.added, isEmpty);
      expect(stored().part, _oddSide);
      expect(labels(stored()), ['5', '7']);
      expect(streets.saved.single, (stored(), change));
    });

    test('should ask nothing when the numbers leaving have no marks', () async {
      // 7 is to do: it goes without a question.
      final change = valueOf(
        await changePart(lilasId, part(odd: range(5, 5), even: SidePart.all)),
      );

      expect(change.removed, [RemovedHouse(house: seven, removal: leaAtTwo)]);
      expect(labels(stored()), ['5', '8']);
    });

    test('should read nothing from the BAN, so it works offline', () async {
      useDirectory(const Err(AddressDirectoryFailure.noNetwork));

      valueOf(await changePart(lilasId, _oddSide, marksConfirmed: true));

      expect(directory.streetsAsked, isEmpty);
      expect(stored().part, _oddSide);
    });
  });

  group('widening', () {
    test('should bring back the Corbeille and add the numbers the BAN '
        'gives', () async {
      await keepOnlyTheOddSide();

      final change = valueOf(await changePart(lilasId, StreetPart.whole));

      expect(directory.streetsAsked, [_lilasBan]);
      expect(change.restored, [RemovedHouse(house: eight, removal: leaAtTwo)]);
      expect(change.added, [House(number: n('10'), position: northDoor)]);
      expect(labels(stored()), ['5', '7', '8', '10']);
      expect(stored().houseAt(n('8')), eight);
      expect(stored().part, StreetPart.whole);
      expect(streets.saved.single, (stored(), change));
    });

    test('should change nothing offline', () async {
      await keepOnlyTheOddSide();
      useDirectory(const Err(AddressDirectoryFailure.noNetwork));

      expect(
        failureOf(await changePart(lilasId, StreetPart.whole)),
        const NumbersUnreadable(AddressDirectoryFailure.noNetwork),
      );
      expect(streets.saved, isEmpty);
      expect(stored().part, _oddSide);
    });

    test('should say why the BAN could not give the numbers', () async {
      await keepOnlyTheOddSide();
      useDirectory(const Err(AddressDirectoryFailure.serviceError));

      expect(
        failureOf(await changePart(lilasId, StreetPart.whole)),
        const NumbersUnreadable(AddressDirectoryFailure.serviceError),
      );
    });

    test('should only bring back the Corbeille on a street typed by '
        'hand', () async {
      final manual = Street.manual(
        id: StreetId('chemin-du-bois'),
        name: streetName('Chemin du Bois'),
        commune: villefranche,
        numbers: [n('1'), n('2')],
      );
      streets = FakeStreetRepository([manual]);
      useDirectory(const Err(AddressDirectoryFailure.noNetwork));
      valueOf(await changePart(manual.id, _oddSide));

      final change = valueOf(await changePart(manual.id, StreetPart.whole));

      expect(directory.streetsAsked, isEmpty);
      expect(change.restored.map((back) => back.number), [n('2')]);
      expect(change.added, isEmpty);
    });

    test(
      'should keep a teammate\'s mark made while the BAN answered',
      () async {
        await keepOnlyTheOddSide();
        directory.holdStreet(_lilasBan);
        final widening = changePart(lilasId, StreetPart.whole);
        // Paul marks 7 while the numbers are on their way.
        final (marked, mark) = valueOf(
          stored().markHouse(n('7'), VisitStatus.done, by: paul, at: threePm),
        );
        await streets.save(marked, mark);
        directory.releaseStreet(_lilasBan);

        valueOf(await widening);

        expect(stored().houseAt(n('7'))!.status, VisitStatus.done);
        expect(stored().part, StreetPart.whole);
      },
    );

    test('should say the part is the same when a teammate gave it while the '
        'BAN answered', () async {
      await keepOnlyTheOddSide();
      directory.holdStreet(_lilasBan);
      final widening = changePart(lilasId, StreetPart.whole);
      final (whole, change) = valueOf(
        stored().changePart(StreetPart.whole, by: paul, at: threePm),
      );
      await streets.save(whole, change);
      directory.releaseStreet(_lilasBan);

      expect(failureOf(await widening), const SamePart());
    });

    test('should say the street is gone when it was purged while the BAN '
        'answered', () async {
      await keepOnlyTheOddSide();
      directory.holdStreet(_lilasBan);
      final widening = changePart(lilasId, StreetPart.whole);
      await streets.purge(lilasId);
      directory.releaseStreet(_lilasBan);

      expect(failureOf(await widening), const PartOfUnknownStreet());
    });
  });

  test('should say the part is the same, changing nothing', () async {
    expect(
      failureOf(await changePart(lilasId, StreetPart.whole)),
      const SamePart(),
    );
    expect(streets.saved, isEmpty);
    expect(directory.streetsAsked, isEmpty);
  });

  test('should say the street is unknown', () async {
    expect(
      failureOf(await changePart(StreetId('rue-inconnue'), _oddSide)),
      const PartOfUnknownStreet(),
    );
  });

  group('refusals', () {
    test('should be equal by value and name themselves', () {
      expect(const PartOfUnknownStreet(), const PartOfUnknownStreet());
      expect(
        const PartOfUnknownStreet().hashCode,
        const PartOfUnknownStreet().hashCode,
      );
      expect(const SamePart(), isNot(const PartOfUnknownStreet()));
      expect(const SamePart().hashCode, const SamePart().hashCode);
      expect(MarkedNumbersLeaving([n('8')]), MarkedNumbersLeaving([n('8')]));
      expect(
        MarkedNumbersLeaving([n('8')]).hashCode,
        MarkedNumbersLeaving([n('8')]).hashCode,
      );
      expect(
        MarkedNumbersLeaving([n('8')]),
        isNot(MarkedNumbersLeaving([n('8'), n('10')])),
      );
      expect(
        const NumbersUnreadable(AddressDirectoryFailure.noNetwork),
        isNot(const NumbersUnreadable(AddressDirectoryFailure.notFound)),
      );
      expect(
        const NumbersUnreadable(AddressDirectoryFailure.noNetwork).hashCode,
        const NumbersUnreadable(AddressDirectoryFailure.noNetwork).hashCode,
      );
      expect('${const PartOfUnknownStreet()}', 'PartOfUnknownStreet');
      expect('${const SamePart()}', 'SamePart');
      expect(
        '${MarkedNumbersLeaving([n('8'), n('10')])}',
        'MarkedNumbersLeaving(8, 10)',
      );
      expect(
        '${const NumbersUnreadable(AddressDirectoryFailure.noNetwork)}',
        'NumbersUnreadable(AddressDirectoryFailure.noNetwork)',
      );
    });

    test('should keep the numbers given when the list changes after', () {
      final numbers = [n('8')];
      final refusal = MarkedNumbersLeaving(numbers);
      numbers.add(n('10'));

      expect(refusal.numbers, [n('8')]);
    });
  });
}

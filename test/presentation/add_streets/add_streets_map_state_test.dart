import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_shape.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';

import '../../support/geo_fixtures.dart';
import '../../support/street_fixtures.dart' show part, range;

final _morin = FoundStreetRow(
  id: BanStreetId('69264_1460'),
  name: 'Rue Pierre Morin',
  commune: 'Villefranche-sur-Saône',
);

void main() {
  group('the dot on the map', () {
    final looking = at(45.98850, 4.72500);
    final tapped = at(45.98915, 4.71862);
    final card = StreetCardInSector(
      id: StreetId('nationale'),
      name: 'Rue Nationale',
      commune: 'Villefranche-sur-Saône',
      done: 0,
      total: 1,
    );

    test('should mark the point looked up with no card', () {
      final state = AddStreetsMapState(
        layers: MapLayers.of(const []),
        area: null,
        lookingAt: looking,
      );

      expect(state.selectedPoint, looking);
      expect(state.card, isNull);
      expect(state.cardRoad, StreetShape.none);
      expect(state.cardPoint, isNull);
    });

    test('should mark where the street of the card was tapped while it '
        'shows', () {
      final state = AddStreetsMapState(
        layers: MapLayers.of(const []),
        area: null,
        lookingAt: looking,
        card: card,
        cardPoint: tapped,
      );

      expect(state.selectedPoint, tapped);
    });
  });

  test('should tell the search states apart by their values', () {
    expect(const NoStreetSearch(), const NoStreetSearch());
    expect(const NoStreetSearch().hashCode, const NoStreetSearch().hashCode);
    expect(const SearchingStreets(), const SearchingStreets());
    expect(
      const SearchingStreets().hashCode,
      const SearchingStreets().hashCode,
    );
    expect(const SearchingStreets(), isNot(const NoStreetSearch()));
    expect(StreetsFound([_morin]), StreetsFound([_morin]));
    expect(StreetsFound([_morin]).hashCode, StreetsFound([_morin]).hashCode);
    expect(StreetsFound([_morin]), isNot(StreetsFound(const [])));
    expect(
      const StreetSearchFailed(LookUpProblem.noNetwork),
      const StreetSearchFailed(LookUpProblem.noNetwork),
    );
    expect(
      const StreetSearchFailed(LookUpProblem.noNetwork).hashCode,
      const StreetSearchFailed(LookUpProblem.noNetwork).hashCode,
    );
    expect(
      const StreetSearchFailed(LookUpProblem.noNetwork),
      isNot(const StreetSearchFailed(LookUpProblem.serviceError)),
    );
  });

  test('should equal a found street with the same values only', () {
    FoundStreetRow row({
      String id = '69264_1460',
      String name = 'Rue Pierre Morin',
      String commune = 'Villefranche-sur-Saône',
    }) => FoundStreetRow(id: BanStreetId(id), name: name, commune: commune);

    expect(row(), _morin);
    expect(row().hashCode, _morin.hashCode);
    expect(row(id: '69264_0246'), isNot(_morin));
    expect(row(name: 'Rue Pasteur'), isNot(_morin));
    expect(row(commune: 'Gleizé'), isNot(_morin));
    expect(_morin.toString(), contains('Rue Pierre Morin'));
  });

  test('should equal a picked street with the same values only', () {
    PickedStreetRow row({
      String id = '69264_1460',
      String name = 'Rue Pierre Morin',
      String commune = 'Villefranche-sur-Saône',
      int numberCount = 19,
    }) => PickedStreetRow(
      id: BanStreetId(id),
      name: name,
      commune: commune,
      numberCount: numberCount,
    );

    expect(row(), row());
    expect(row().hashCode, row().hashCode);
    expect(row(id: '69264_0246'), isNot(row()));
    expect(row(name: 'Rue Pasteur'), isNot(row()));
    expect(row(commune: 'Gleizé'), isNot(row()));
    expect(row(numberCount: 18), isNot(row()));
    expect(
      row().toString(),
      'PickedStreetRow(69264_1460, Rue Pierre Morin, 19)',
    );
  });

  group('the part of a picked street (PLAN §5.15)', () {
    final evens = part(odd: SidePart.none, even: range(2, 8));

    PickedStreetRow row({
      StreetPart part = StreetPart.whole,
      int? keptCount,
      bool readingPart = false,
      bool fromCorbeille = false,
    }) => PickedStreetRow(
      id: BanStreetId('69264_1460'),
      name: 'Impasse des Tilleuls',
      commune: 'Villefranche-sur-Saône',
      numberCount: 8,
      part: part,
      keptCount: keptCount,
      readingPart: readingPart,
      fromCorbeille: fromCorbeille,
    );

    test('should hold the whole street, being read and from the Corbeille '
        'by no default', () {
      final plain = PickedStreetRow(
        id: BanStreetId('69264_1460'),
        name: 'Impasse des Tilleuls',
        commune: 'Villefranche-sur-Saône',
        numberCount: 8,
      );

      expect(plain.part, StreetPart.whole);
      expect(plain.keptCount, isNull);
      expect(plain.readingPart, isFalse);
      expect(plain.fromCorbeille, isFalse);
      expect(plain.others, isEmpty);
    });

    test('should tell the rows apart by the other secteurs holding the '
        'street, and print them', () {
      final twelve = OtherSectorLine(sector: 12, part: evens);
      PickedStreetRow held(List<OtherSectorLine> others) => PickedStreetRow(
        id: BanStreetId('69264_1460'),
        name: 'Impasse des Tilleuls',
        commune: 'Villefranche-sur-Saône',
        numberCount: 8,
        others: others,
      );

      expect(held([twelve]), held([OtherSectorLine(sector: 12, part: evens)]));
      expect(held([twelve]).hashCode, held([twelve]).hashCode);
      expect(held([twelve]), isNot(row()));
      expect(
        held([twelve]),
        isNot(held([OtherSectorLine(sector: 3, part: evens)])),
      );
      expect(
        held([twelve]).toString(),
        'PickedStreetRow(69264_1460, Impasse des Tilleuls, 8, others: '
        '[OtherSectorLine(12, null, StreetPart(odd: none, even: 2–8))])',
      );
    });

    test('should tell the rows apart by their part', () {
      final chosen = row(part: evens, keptCount: 4);

      expect(chosen, row(part: evens, keptCount: 4));
      expect(chosen.hashCode, row(part: evens, keptCount: 4).hashCode);
      expect(chosen, isNot(row(keptCount: 4)));
      expect(chosen, isNot(row(part: evens, keptCount: 5)));
      expect(row(readingPart: true), isNot(row()));
      expect(row(fromCorbeille: true), isNot(row()));
    });

    test('should print what it says of its part', () {
      expect(
        row(part: evens, keptCount: 4).toString(),
        'PickedStreetRow(69264_1460, Impasse des Tilleuls, 8, '
        'StreetPart(odd: none, even: 2–8), kept: 4)',
      );
      expect(
        row(readingPart: true, fromCorbeille: true).toString(),
        'PickedStreetRow(69264_1460, Impasse des Tilleuls, 8, reading, '
        'from the Corbeille)',
      );
    });
  });

  test('should tell the answers to a tap apart by their values', () {
    // Built at run time, not as constants, so their constructors run.
    // ignore: prefer_const_constructors
    expect(NothingToSay(), const NothingToSay());
    expect(const NothingToSay().hashCode, const NothingToSay().hashCode);
    expect(
      // ignore: prefer_const_constructors
      LookUpFailed(LookUpProblem.noNetwork),
      const LookUpFailed(LookUpProblem.noNetwork),
    );
    expect(
      const LookUpFailed(LookUpProblem.noNetwork).hashCode,
      const LookUpFailed(LookUpProblem.noNetwork).hashCode,
    );
    expect(
      const LookUpFailed(LookUpProblem.noNetwork),
      isNot(const LookUpFailed(LookUpProblem.serviceError)),
    );
    expect(
      const LookUpFailed(LookUpProblem.noStreetHere).toString(),
      'LookUpFailed(noStreetHere)',
    );
  });

  test('should tell the runs apart by their values', () {
    // ignore: prefer_const_constructors
    expect(AddIdle(), const AddIdle());
    expect(const AddIdle().hashCode, const AddIdle().hashCode);
    // ignore: prefer_const_constructors
    expect(AddRunning(2, 3), const AddRunning(2, 3));
    expect(const AddRunning(2, 3).hashCode, const AddRunning(2, 3).hashCode);
    expect(const AddRunning(2, 3), isNot(const AddRunning(1, 3)));
    expect(const AddRunning(2, 3), isNot(const AddRunning(2, 4)));
    expect(const AddRunning(2, 3).toString(), 'AddRunning(2/3)');
    // ignore: prefer_const_constructors
    expect(AddFailed(2), const AddFailed(2));
    expect(const AddFailed(2).hashCode, const AddFailed(2).hashCode);
    expect(const AddFailed(2), isNot(const AddFailed(1)));
    expect(const AddFailed(2), isNot(const AddIdle()));
    expect(const AddFailed(2).toString(), 'AddFailed(2, badNumbers)');
    expect(
      const AddFailed(2, problem: AddProblem.noNetwork),
      isNot(const AddFailed(2)),
    );
    expect(
      const AddFailed(2, problem: AddProblem.noNetwork).hashCode,
      const AddFailed(2, problem: AddProblem.noNetwork).hashCode,
    );
    expect(const AddFailed(2).problem, AddProblem.badNumbers);
  });

  test('should tell the zone answers apart', () {
    // ignore: prefer_const_constructors
    expect(ZoneTooLarge(), const ZoneTooLarge());
    expect(const ZoneTooLarge().hashCode, const ZoneTooLarge().hashCode);
    expect(const ZoneTooLarge(), isNot(const NothingToSay()));
  });

  group('the zone', () {
    final area = GeoBounds.of(
      south: 45.98,
      west: 4.71,
      north: 45.99,
      east: 4.73,
    )!;
    final other = GeoBounds.of(
      south: 45.97,
      west: 4.71,
      north: 45.99,
      east: 4.73,
    )!;
    ZoneStreetRow row({
      ZoneRowKind kind = ZoneRowKind.toAdd,
      String name = 'Rue Pierre Morin',
      String? id = '69264_1460',
      int numberCount = 19,
      bool ticked = true,
    }) => ZoneStreetRow(
      kind: kind,
      name: name,
      id: id == null ? null : BanStreetId(id),
      numberCount: numberCount,
      ticked: ticked,
    );

    test('should have no area without a zone', () {
      // ignore: prefer_const_constructors
      expect(NoZone(), const NoZone());
      expect(const NoZone().hashCode, const NoZone().hashCode);
      expect(const NoZone().area, isNull);
    });

    test('should tell the zones being looked at apart by their area', () {
      expect(FindingZoneStreets(area), FindingZoneStreets(area));
      expect(
        FindingZoneStreets(area).hashCode,
        FindingZoneStreets(area).hashCode,
      );
      expect(FindingZoneStreets(area), isNot(FindingZoneStreets(other)));
      expect(FindingZoneStreets(area).area, area);
    });

    test('should tell the zones found apart by their area and rows', () {
      expect(ZoneStreetsFound(area, [row()]), ZoneStreetsFound(area, [row()]));
      expect(
        ZoneStreetsFound(area, [row()]).hashCode,
        ZoneStreetsFound(area, [row()]).hashCode,
      );
      expect(
        ZoneStreetsFound(area, [row()]),
        isNot(ZoneStreetsFound(other, [row()])),
      );
      expect(
        ZoneStreetsFound(area, [row()]),
        isNot(ZoneStreetsFound(area, [row(ticked: false)])),
      );
      expect(ZoneStreetsFound(area, [row()]).area, area);
      expect(
        () => ZoneStreetsFound(area, [row()]).rows.add(row()),
        throwsUnsupportedError,
      );
    });

    test('should tell the rows apart by each field', () {
      expect(row(), row());
      expect(row().hashCode, row().hashCode);
      expect(row(kind: ZoneRowKind.inSector), isNot(row()));
      expect(row(name: 'Rue Pasteur'), isNot(row()));
      expect(row(id: '69264_1200'), isNot(row()));
      expect(row(id: null), isNot(row()));
      expect(row(numberCount: 8), isNot(row()));
      expect(row(ticked: false), isNot(row()));
      expect(
        row().toString(),
        'ZoneStreetRow(toAdd, Rue Pierre Morin, 69264_1460, 19, true)',
      );
    });

    test('should tell the rows apart by their part', () {
      final evens = part(odd: SidePart.none, even: range(2, 8));
      ZoneStreetRow parted({
        StreetPart part = StreetPart.whole,
        int? keptCount,
        bool readingPart = false,
        bool fromCorbeille = false,
      }) => ZoneStreetRow(
        kind: ZoneRowKind.toAdd,
        name: 'Impasse des Tilleuls',
        id: BanStreetId('69264_1460'),
        numberCount: 8,
        ticked: true,
        part: part,
        keptCount: keptCount,
        readingPart: readingPart,
        fromCorbeille: fromCorbeille,
      );

      expect(
        parted(part: evens, keptCount: 4),
        parted(part: evens, keptCount: 4),
      );
      expect(
        parted(part: evens, keptCount: 4).hashCode,
        parted(part: evens, keptCount: 4).hashCode,
      );
      expect(parted(part: evens, keptCount: 4), isNot(parted(keptCount: 4)));
      expect(
        parted(part: evens, keptCount: 4),
        isNot(parted(part: evens, keptCount: 3)),
      );
      expect(parted(readingPart: true), isNot(parted()));
      expect(parted(fromCorbeille: true), isNot(parted()));
      final twelve = [OtherSectorLine(sector: 12, part: evens)];
      final held = ZoneStreetRow(
        kind: ZoneRowKind.toAdd,
        name: 'Impasse des Tilleuls',
        id: BanStreetId('69264_1460'),
        numberCount: 8,
        ticked: true,
        others: twelve,
      );
      expect(held, isNot(parted()));
      expect(
        held.hashCode,
        ZoneStreetRow(
          kind: ZoneRowKind.toAdd,
          name: 'Impasse des Tilleuls',
          id: BanStreetId('69264_1460'),
          numberCount: 8,
          ticked: true,
          others: [OtherSectorLine(sector: 12, part: evens)],
        ).hashCode,
      );
      expect(held.toString(), contains(', others: [OtherSectorLine(12'));
      expect(
        parted(part: evens, keptCount: 4, readingPart: true).toString(),
        'ZoneStreetRow(toAdd, Impasse des Tilleuls, 69264_1460, 8, true, '
        'StreetPart(odd: none, even: 2–8), kept: 4, reading)',
      );
    });

    test('should have a row with no id, no number and no tick by default', () {
      const row = ZoneStreetRow(kind: ZoneRowKind.noAddress, name: 'Chemin');

      expect(row.id, isNull);
      expect(row.numberCount, 0);
      expect(row.ticked, isFalse);
      expect(row.part, StreetPart.whole);
      expect(row.keptCount, isNull);
      expect(row.readingPart, isFalse);
      expect(row.fromCorbeille, isFalse);
      expect(row.others, isEmpty);
    });

    test('should be off with no zone by default', () {
      final state = AddStreetsMapState(
        layers: MapLayers.of(const []),
        area: null,
      );

      expect(state.zoneMode, isFalse);
      expect(state.zone, const NoZone());
    });
  });

  test('should be adding only while the streets are being stored', () {
    AddStreetsMapState withRun(AddRun run) => AddStreetsMapState(
      layers: MapLayers.of(const []),
      area: null,
      run: run,
    );

    expect(withRun(const AddRunning(0, 2)).adding, isTrue);
    expect(withRun(const AddIdle()).adding, isFalse);
    expect(withRun(const AddFailed(1)).adding, isFalse);
  });
}

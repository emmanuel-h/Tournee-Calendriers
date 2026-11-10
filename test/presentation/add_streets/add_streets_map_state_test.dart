import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';

final _morin = FoundStreetRow(
  id: BanStreetId('69264_1460'),
  name: 'Rue Pierre Morin',
  commune: 'Villefranche-sur-Saône',
);

void main() {
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

  test('should tell the answers to a tap apart by their values', () {
    // Built at run time, not as constants, so their constructors run.
    // ignore: prefer_const_constructors
    expect(NothingToSay(), const NothingToSay());
    expect(const NothingToSay().hashCode, const NothingToSay().hashCode);
    expect(
      // ignore: prefer_const_constructors
      AlreadyInSector('Rue des Lilas'),
      const AlreadyInSector('Rue des Lilas'),
    );
    expect(
      const AlreadyInSector('Rue des Lilas').hashCode,
      const AlreadyInSector('Rue des Lilas').hashCode,
    );
    expect(
      const AlreadyInSector('Rue des Lilas'),
      isNot(const AlreadyInSector('Rue Pasteur')),
    );
    expect(const AlreadyInSector('Rue des Lilas'), isNot(const NothingToSay()));
    expect(
      const AlreadyInSector('Rue des Lilas').toString(),
      'AlreadyInSector(Rue des Lilas)',
    );
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
    expect(const AddFailed(2).toString(), 'AddFailed(2)');
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

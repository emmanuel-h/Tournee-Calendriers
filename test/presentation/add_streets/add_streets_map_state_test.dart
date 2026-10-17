import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/add_streets/add_streets_map_state.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';

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
}

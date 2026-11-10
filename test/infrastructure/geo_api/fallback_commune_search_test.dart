import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/commune_search.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/infrastructure/geo_api/fallback_commune_search.dart';

import '../../support/results.dart';
import '../../support/street_fixtures.dart';

/// A [CommuneSearch] giving [answer] and noting each name it is asked.
final class _Answering implements CommuneSearch {
  _Answering(this.answer);

  final Result<List<CommuneMatch>, CommuneSearchFailure> answer;
  final asked = <String>[];

  @override
  Future<Result<List<CommuneMatch>, CommuneSearchFailure>> search(
    String name,
  ) async {
    asked.add(name);
    return answer;
  }
}

void main() {
  final fromFirst = [
    CommuneMatch(commune: villefranche, postcodes: const ['69400', '69401']),
  ];
  final fromSecond = [
    CommuneMatch(commune: villefranche, postcodes: const ['69400']),
  ];

  test('should give the first answer without asking the second', () async {
    final first = _Answering(Ok(fromFirst));
    final second = _Answering(Ok(fromSecond));

    final found = await FallbackCommuneSearch(first, second).search('Ville');

    expect(valueOf(found), fromFirst);
    expect(first.asked, ['Ville']);
    expect(second.asked, isEmpty);
  });

  test('should give the first answer when it found nothing', () async {
    final second = _Answering(Ok(fromSecond));

    final found = await FallbackCommuneSearch(
      _Answering(const Ok([])),
      second,
    ).search('zzzzqx');

    expect(valueOf(found), isEmpty);
    expect(second.asked, isEmpty);
  });

  for (final failure in CommuneSearchFailure.values) {
    test('should ask the second when the first fails with $failure', () async {
      final second = _Answering(Ok(fromSecond));

      final found = await FallbackCommuneSearch(
        _Answering(Err(failure)),
        second,
      ).search('Ville');

      expect(valueOf(found), fromSecond);
      expect(second.asked, ['Ville']);
    });
  }

  final both = {
    (CommuneSearchFailure.noNetwork, CommuneSearchFailure.noNetwork):
        CommuneSearchFailure.noNetwork,
    (CommuneSearchFailure.serviceError, CommuneSearchFailure.noNetwork):
        CommuneSearchFailure.serviceError,
    (CommuneSearchFailure.noNetwork, CommuneSearchFailure.serviceError):
        CommuneSearchFailure.serviceError,
    (CommuneSearchFailure.serviceError, CommuneSearchFailure.serviceError):
        CommuneSearchFailure.serviceError,
  };
  both.forEach((failures, expected) {
    final (firstFailure, secondFailure) = failures;
    test('should fail with $expected when the first fails with '
        '$firstFailure and the second with $secondFailure', () async {
      final found = await FallbackCommuneSearch(
        _Answering(Err(firstFailure)),
        _Answering(Err(secondFailure)),
      ).search('Ville');

      expect(failureOf(found), expected);
    });
  });
}

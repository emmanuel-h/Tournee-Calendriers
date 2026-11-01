// The tournées downloaded on this phone (PLAN §6.3) ⇄ the JSON of
// `tournee_downloads.json`.
import 'package:test/test.dart';
import 'package:tournee_calendriers/application/ports/tournee_downloads.dart';
import 'package:tournee_calendriers/domain/geometry/geo_bounds.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/tournee_downloads_json_mapper.dart';

import '../../../support/geo_fixtures.dart';

final _area = GeoBounds.around([at(45.98, 4.70), at(45.99, 4.72)])!;

final _t49 = TourneeDownload(
  tournee: TourneeId('t49'),
  downloadedAt: DateTime.utc(2026, 11, 2, 8, 12),
  mapBytes: 6600000,
  area: _area,
);

final _t12 = TourneeDownload(
  tournee: TourneeId('t12'),
  downloadedAt: DateTime.utc(2026, 10, 30, 18),
  mapBytes: 0,
  area: null,
);

const _t49Json = {
  'tournee': 't49',
  'at': '2026-11-02T08:12:00.000Z',
  'mapBytes': 6600000,
  'area': [45.98, 4.70, 45.99, 4.72],
};

const _t12Json = {
  'tournee': 't12',
  'at': '2026-10-30T18:00:00.000Z',
  'mapBytes': 0,
  'area': null,
};

void main() {
  test('should write every download, sorted by tournée', () {
    expect(tourneeDownloadsToJson({_t49.tournee: _t49, _t12.tournee: _t12}), {
      'version': 1,
      'downloads': [_t12Json, _t49Json],
    });
  });

  test('should write the time in UTC', () {
    final local = TourneeDownload(
      tournee: TourneeId('t49'),
      downloadedAt: DateTime.utc(2026, 11, 2, 8, 12).toLocal(),
      mapBytes: 1,
      area: null,
    );

    final json = tourneeDownloadsToJson({local.tournee: local});

    expect(
      ((json['downloads']! as List).single as Map)['at'],
      '2026-11-02T08:12:00.000Z',
    );
  });

  test('should read what it wrote', () {
    final downloads = {_t49.tournee: _t49, _t12.tournee: _t12};

    expect(tourneeDownloadsFromJson(tourneeDownloadsToJson(downloads)), {
      TourneeId('t49'): _t49,
      TourneeId('t12'): _t12,
    });
  });

  test('should read a download with every field', () {
    final read = tourneeDownloadsFromJson({
      'version': 1,
      'downloads': [_t49Json],
    })[TourneeId('t49')]!;

    expect(read.tournee, TourneeId('t49'));
    expect(read.downloadedAt, DateTime.utc(2026, 11, 2, 8, 12));
    expect(read.downloadedAt.isUtc, isTrue);
    expect(read.mapBytes, 6600000);
    expect(read.area, _area);
  });

  test('should read whole numbers as coordinates', () {
    final read = tourneeDownloadsFromJson({
      'version': 1,
      'downloads': [
        {
          ..._t49Json,
          'area': [45, 4, 46, 5],
        },
      ],
    });

    expect(
      read[TourneeId('t49')]!.area,
      GeoBounds.around([at(45, 4), at(46, 5)]),
    );
  });

  final unreadable = <String, Object?>{
    'another version': {'version': 2, 'downloads': <Object?>[]},
    'no list': {'version': 1},
    'a download not an object': {
      'version': 1,
      'downloads': ['t49'],
    },
    'a blank tournée': {
      'version': 1,
      'downloads': [
        {..._t49Json, 'tournee': ' '},
      ],
    },
    'a time not a time': {
      'version': 1,
      'downloads': [
        {..._t49Json, 'at': 'lundi'},
      ],
    },
    'a negative size': {
      'version': 1,
      'downloads': [
        {..._t49Json, 'mapBytes': -1},
      ],
    },
    'an area of three numbers': {
      'version': 1,
      'downloads': [
        {
          ..._t49Json,
          'area': [45.98, 4.70, 45.99],
        },
      ],
    },
    'an area out of range': {
      'version': 1,
      'downloads': [
        {
          ..._t49Json,
          'area': [45.98, 4.70, 95.0, 4.72],
        },
      ],
    },
    'an area not numbers': {
      'version': 1,
      'downloads': [
        {
          ..._t49Json,
          'area': ['a', 4.70, 45.99, 4.72],
        },
      ],
    },
    'not an object': 'downloads',
  };
  for (final MapEntry(key: what, value: json) in unreadable.entries) {
    test('should refuse $what', () {
      expect(
        () => tourneeDownloadsFromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  }

  test('should read a size of 0', () {
    final read = tourneeDownloadsFromJson({
      'version': 1,
      'downloads': [
        {..._t49Json, 'mapBytes': 0},
      ],
    });

    expect(read[TourneeId('t49')]!.mapBytes, 0);
  });
}

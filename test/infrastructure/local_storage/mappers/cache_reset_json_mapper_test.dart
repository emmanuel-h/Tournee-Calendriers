import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/cache_reset_json_mapper.dart';

void main() {
  group('cacheResetToJson', () {
    test('should write each step under a fixed name', () {
      expect(cacheResetToJson(CacheResetStep.none), {
        'version': 1,
        'reset': 'none',
      });
      expect(cacheResetToJson(CacheResetStep.waiting), {
        'version': 1,
        'reset': 'waiting',
      });
      expect(cacheResetToJson(CacheResetStep.due), {
        'version': 1,
        'reset': 'due',
      });
    });
  });

  group('cacheResetFromJson', () {
    test('should read back each step', () {
      for (final step in CacheResetStep.values) {
        expect(cacheResetFromJson(cacheResetToJson(step)), step);
      }
    });

    test('should refuse a step it does not know', () {
      expect(
        () => cacheResetFromJson({'version': 1, 'reset': 'soon'}),
        throwsFormatException,
      );
    });

    test('should refuse another version', () {
      expect(
        () => cacheResetFromJson({'version': 2, 'reset': 'due'}),
        throwsFormatException,
      );
    });

    test('should refuse what is not the schema', () {
      expect(() => cacheResetFromJson({'version': 1}), throwsFormatException);
      expect(() => cacheResetFromJson('due'), throwsFormatException);
      expect(() => cacheResetFromJson(null), throwsFormatException);
    });
  });
}

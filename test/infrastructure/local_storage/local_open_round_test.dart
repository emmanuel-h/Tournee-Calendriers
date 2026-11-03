import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/local_open_round.dart';
import 'package:tournee_calendriers/infrastructure/local_storage/mappers/open_round_json_mapper.dart';

import '../../domain/round/round_fixtures.dart';

void main() {
  late Directory folder;
  late File file;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('open_round_test');
    // In a folder not made yet, as on a first launch.
    file = File('${folder.path}/storage/open_round.json');
  });

  tearDown(() => folder.delete(recursive: true));

  test('should have no tournée on when the file does not exist', () async {
    final store = await LocalOpenRound.load(file);

    expect(store.openRound, isNull);
    expect(file.existsSync(), isFalse);
  });

  test('should answer at once, tell listeners and keep the tournée on the '
      'phone', () async {
    final store = await LocalOpenRound.load(file);
    final heard = <Round?>[];
    store.changes.listen(heard.add);
    final round = newRound().add(cash(1000));

    final saving = store.save(round);
    expect(store.openRound, round);
    await saving;

    expect(heard, [round]);
    expect(jsonDecode(file.readAsStringSync()), openRoundToJson(round));
  });

  test('should find the tournée again after a kill', () async {
    final first = await LocalOpenRound.load(file);
    await first.save(newRound());
    await first.save(newRound().visited().add(offered));

    final next = await LocalOpenRound.load(file);

    expect(next.openRound, newRound().visited().add(offered));
  });

  test('should forget the tournée and its dons once cleared', () async {
    final first = await LocalOpenRound.load(file);
    final heard = <Round?>[];
    first.changes.listen(heard.add);
    await first.save(newRound().add(cash(1000)));

    await first.clear();

    expect(first.openRound, isNull);
    expect(heard, [newRound().add(cash(1000)), null]);
    expect((await LocalOpenRound.load(file)).openRound, isNull);
    expect(jsonDecode(file.readAsStringSync()), {'version': 1, 'round': null});
  });

  test(
    'should have none, and leave the file, when it cannot be read',
    () async {
      for (final text in ['not json', '{"version": 2, "round": null}']) {
        file
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(text);

        final store = await LocalOpenRound.load(file);

        expect(store.openRound, isNull, reason: text);
        expect(file.readAsStringSync(), text);
      }
    },
  );
}

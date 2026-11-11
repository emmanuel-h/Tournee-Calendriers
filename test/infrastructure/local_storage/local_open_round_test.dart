import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/round/round.dart';
import 'package:tournee_calendriers/domain/round/unsent_round.dart';
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
    expect(
      jsonDecode(file.readAsStringSync()),
      roundsToJson((open: round, unsent: const [])),
    );
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
    expect(jsonDecode(file.readAsStringSync()), {
      'version': 2,
      'round': null,
      'unsent': <Object?>[],
    });
  });

  test('should have none, say so, and leave the file, when it cannot be '
      'read', () async {
    for (final text in ['not json', '{"version": 3, "round": null}']) {
      file
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(text);

      final store = await LocalOpenRound.load(file);

      expect(store.openRound, isNull, reason: text);
      expect(store.unsent, isEmpty, reason: text);
      expect(store.unreadableAtStart, isTrue, reason: text);
      expect(file.readAsStringSync(), text);
    }
  });

  test(
    'should not say unreadable when there is no file or it is read',
    () async {
      expect((await LocalOpenRound.load(file)).unreadableAtStart, isFalse);

      await (await LocalOpenRound.load(file)).save(newRound());

      expect((await LocalOpenRound.load(file)).unreadableAtStart, isFalse);
    },
  );

  test('should read the file of an older version', () async {
    file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"version": 1, "round": null}');

    final store = await LocalOpenRound.load(file);

    expect(store.unreadableAtStart, isFalse);
    expect(store.openRound, isNull);
  });

  group('validated tournées not yet sent', () {
    final validated = newRound().add(cash(1000)).validate(endedAt);

    test('should move the tournée on to those waiting, in one write, and '
        'find it after a kill', () async {
      final store = await LocalOpenRound.load(file);
      final heardOn = <Round?>[];
      final heardUnsent = <List<UnsentRound>>[];
      store.changes.listen(heardOn.add);
      store.unsentChanges.listen(heardUnsent.add);
      await store.save(newRound().add(cash(1000)));

      final keeping = store.keepValidated(validated);
      expect(store.openRound, isNull);
      expect(store.unsent, [validated]);
      await keeping;

      expect(heardOn, [newRound().add(cash(1000)), null]);
      expect(heardUnsent, [
        [validated],
      ]);
      final next = await LocalOpenRound.load(file);
      expect(next.openRound, isNull);
      expect(next.unsent, [validated]);
    });

    test('should keep a tournée started after, and those waiting', () async {
      final store = await LocalOpenRound.load(file);
      await store.save(newRound());
      await store.keepValidated(validated);

      await store.save(newRound().visited());

      final next = await LocalOpenRound.load(file);
      expect(next.openRound, newRound().visited());
      expect(next.unsent, [validated]);
    });

    test('should replace one validated again under the same id', () async {
      final store = await LocalOpenRound.load(file);
      await store.keepValidated(validated.refused());

      await store.keepValidated(validated);

      expect(store.unsent, [validated]);
    });

    test('should mark one refused, keeping the tournée on as it is', () async {
      final store = await LocalOpenRound.load(file);
      await store.keepValidated(validated);
      await store.save(newRound().visited());
      final heardOn = <Round?>[];
      store.changes.listen(heardOn.add);

      await store.updateUnsent(validated.refused());
      await pumpEventQueue();

      expect(store.unsent, [validated.refused()]);
      expect(heardOn, isEmpty);
      final next = await LocalOpenRound.load(file);
      expect(next.unsent, [validated.refused()]);
      expect(next.openRound, newRound().visited());
    });

    test('should forget one sent or erased', () async {
      final store = await LocalOpenRound.load(file);
      await store.keepValidated(validated);
      final heardUnsent = <List<UnsentRound>>[];
      store.unsentChanges.listen(heardUnsent.add);

      await store.forgetUnsent(validated.id);
      await pumpEventQueue();

      expect(store.unsent, isEmpty);
      expect(heardUnsent, [<UnsentRound>[]]);
      expect((await LocalOpenRound.load(file)).unsent, isEmpty);
    });

    test('should change nothing for a tournée no longer waiting', () async {
      final store = await LocalOpenRound.load(file);
      final heardUnsent = <List<UnsentRound>>[];
      store.unsentChanges.listen(heardUnsent.add);

      await store.updateUnsent(validated.refused());
      await store.forgetUnsent(validated.id);
      await pumpEventQueue();

      expect(store.unsent, isEmpty);
      expect(heardUnsent, isEmpty);
      expect(file.existsSync(), isFalse);
    });
  });
}

import 'dart:async';

import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/shared/load_then_follow.dart';

void main() {
  late StreamController<String> changes;
  late List<String> loaded;

  setUp(() {
    changes = StreamController<String>.broadcast(sync: true);
    loaded = ['a'];
  });

  tearDown(() => changes.close());

  Stream<String> follow({Future<List<String>> Function()? load}) =>
      loadThenFollow(
        load: load ?? () async => loaded,
        changes: changes.stream,
        concerns: (change) => change != 'other',
        read: (items) => items.join(','),
      );

  test('should give what was loaded, then again after each change', () async {
    final seen = <String>[];
    final subscription = follow().listen(seen.add);
    await pumpEventQueue();

    loaded.add('b');
    changes.add('mine');
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, ['a', 'a,b']);
  });

  test('should ignore a change that does not concern it', () async {
    final seen = <String>[];
    final subscription = follow().listen(seen.add);
    await pumpEventQueue();

    changes.add('other');
    await pumpEventQueue();
    await subscription.cancel();

    expect(seen, ['a']);
  });

  test('should give the failure when the load fails', () async {
    expect(
      follow(load: () async => throw const FormatException('broken')).first,
      throwsFormatException,
    );
  });

  test('should give the failure of the changes', () async {
    final errors = <Object>[];
    final subscription = follow().listen((_) {}, onError: errors.add);
    await pumpEventQueue();

    changes.addError(StateError('refused'));
    await pumpEventQueue();
    await subscription.cancel();

    expect(errors, [isA<StateError>()]);
  });

  test('should give nothing when the listener left before the load', () async {
    final load = Completer<List<String>>();
    final seen = <String>[];
    final subscription = follow(load: () => load.future).listen(seen.add);

    await subscription.cancel();
    load.complete(['late']);
    await pumpEventQueue();

    expect(seen, isEmpty);
    expect(changes.hasListener, isFalse);
  });
}

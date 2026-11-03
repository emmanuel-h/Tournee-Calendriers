// The writes of one phone kept in order per document (#70): each write that
// asks it waits until the phone's copy of the document shows it before the
// next one goes. The copies here are fakes that arrive when the test says,
// late, stale or never, as the Firestore plugin may deliver them.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/infrastructure/firestore/ordered_writes.dart';

/// The fake documents: the copies each test pushes, the writes sent and
/// the failures told.
final class _Documents {
  final _copies = <String, StreamController<Map<String, Object?>?>>{};

  /// How many times each document's copy was listened to.
  final listens = <String, int>{};

  /// The writes sent, by name, in the order they went.
  final sent = <String>[];

  /// What [OrderedWrites] reported for each write sent, by [what].
  final reported = <String>[];

  /// The writes' futures, by name, to complete or fail them.
  final _acks = <String, Completer<void>>{};

  late final writes = OrderedWrites(
    copyOf: (id) {
      listens[id] = (listens[id] ?? 0) + 1;
      return _copyOf(id).stream;
    },
    report: (what, write) {
      reported.add(what);
      // As `sendInBackground` does: the failure is handled, only told.
      unawaited(write.then<void>((_) {}, onError: (Object _) {}));
    },
  );

  StreamController<Map<String, Object?>?> _copyOf(String id) =>
      _copies.putIfAbsent(id, StreamController.broadcast);

  /// The phone's copy of [id] changing to [data].
  Future<void> copy(String id, Map<String, Object?>? data) async {
    _copyOf(id).add(data);
    await pumpEventQueue();
  }

  /// The copy of [id] failing (this member may no longer read it).
  Future<void> copyFails(String id) async {
    _copyOf(id).addError(StateError('permission-denied'));
    await pumpEventQueue();
  }

  /// The copy of [id] closing.
  Future<void> copyCloses(String id) async {
    await _copyOf(id).close();
    await pumpEventQueue();
  }

  /// Whether anyone still follows the copy of [id].
  bool isFollowed(String id) => _copyOf(id).hasListener;

  /// The write [name]: sends it, shown once the copy holds [name] as a key
  /// when [waits].
  OrderedWrite write(String name, {bool waits = true}) => OrderedWrite(() {
    sent.add(name);
    return (_acks[name] = Completer<void>()).future;
  }, isShownIn: waits ? (copy) => copy?.containsKey(name) ?? false : null);

  /// The server refusing the write [name].
  Future<void> refuse(String name) async {
    _acks[name]!.completeError(StateError('permission-denied'));
    await pumpEventQueue();
  }
}

void main() {
  late _Documents docs;

  setUp(() => docs = _Documents());

  group('one batch', () {
    test('should send writes that need not wait all at once, in order', () {
      docs.writes.send('paix', 'save', [
        docs.write('a', waits: false),
        docs.write('b', waits: false),
        docs.write('c', waits: false),
      ]);

      expect(docs.sent, ['a', 'b', 'c']);
      expect(docs.listens, isEmpty);
    });

    test('should send the first write at once and hold back the next until '
        'the copy shows it', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);
      expect(docs.sent, ['a']);

      await docs.copy('paix', {'a': 1});

      expect(docs.sent, ['a', 'b']);
    });

    test('should keep waiting while the copies come late, without the '
        'write', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);

      await docs.copy('paix', null);
      await docs.copy('paix', {'other': 1});

      expect(docs.sent, ['a']);
    });

    test('should send one write per copy that shows the one before, even '
        'when a copy shows several', () async {
      docs.writes.send('paix', 'add', [
        docs.write('a'),
        docs.write('b'),
        docs.write('c'),
      ]);

      // Stale: it already holds `b`, sent after this copy was made.
      await docs.copy('paix', {'a': 1, 'b': 1});
      expect(docs.sent, ['a', 'b']);

      await docs.copy('paix', {'a': 1, 'b': 1});
      expect(docs.sent, ['a', 'b', 'c']);
    });

    test('should send a write that need not wait right after the one '
        'before it', () async {
      docs.writes.send('paix', 'add', [
        docs.write('a'),
        docs.write('b', waits: false),
        docs.write('c'),
        docs.write('d'),
      ]);

      await docs.copy('paix', {'a': 1});

      expect(docs.sent, ['a', 'b', 'c']);
    });

    test('should report every write sent, with what it is for', () async {
      docs.writes.send('paix', 'add paix', [docs.write('a'), docs.write('b')]);
      await docs.copy('paix', {'a': 1});

      expect(docs.reported, ['add paix', 'add paix']);
    });

    test('should follow the copy once per batch and stop when the last '
        'write is shown', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);
      await docs.copy('paix', {'a': 1});
      expect(docs.isFollowed('paix'), isTrue);

      await docs.copy('paix', {'a': 1, 'b': 1});

      expect(docs.listens, {'paix': 1});
      expect(docs.isFollowed('paix'), isFalse);
    });

    test('should send each write once, whatever copies follow', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);

      for (var i = 0; i < 3; i++) {
        await docs.copy('paix', {'a': 1, 'b': 1});
      }

      expect(docs.sent, ['a', 'b']);
    });
  });

  group('stops', () {
    test('should send nothing more once a write is refused', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);

      await docs.refuse('a');
      await docs.copy('paix', {'a': 1});

      expect(docs.sent, ['a']);
      expect(docs.isFollowed('paix'), isFalse);
    });

    test('should send nothing more once the copy fails', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);

      await docs.copyFails('paix');

      expect(docs.sent, ['a']);
      expect(docs.isFollowed('paix'), isFalse);
    });

    test('should send nothing more once the copy closes, and let the next '
        'batch go', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);

      await docs.copyCloses('paix');
      docs.writes.send('paix', 'save', [docs.write('c', waits: false)]);

      expect(docs.sent, ['a', 'c']);
    });

    test('should let the next batch go when a write of the one before is '
        'refused after it was shown', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);
      await docs.copy('paix', {'a': 1});
      await docs.refuse('a');

      docs.writes.send('paix', 'save', [docs.write('c', waits: false)]);

      expect(docs.sent, ['a', 'b', 'c']);
    });
  });

  group('over', () {
    test('should tell the batch over once its last write is shown', () async {
      var over = false;
      docs.writes.send('paix', 'add', [
        docs.write('a'),
        docs.write('b'),
      ], whenOver: () => over = true);

      await docs.copy('paix', {'a': 1});
      expect(over, isFalse);

      await docs.copy('paix', {'a': 1, 'b': 1});
      expect(over, isTrue);
    });

    test('should tell a batch that need not wait over at once', () async {
      var over = false;
      docs.writes.send('paix', 'save', [
        docs.write('a', waits: false),
      ], whenOver: () => over = true);

      await pumpEventQueue();

      expect(over, isTrue);
    });

    test('should tell the batch over when it stops early', () async {
      var over = false;
      docs.writes.send('paix', 'add', [
        docs.write('a'),
        docs.write('b'),
      ], whenOver: () => over = true);

      await docs.refuse('a');

      expect(over, isTrue);
    });

    test('should tell a batch held back over only after its own '
        'writes', () async {
      docs.writes.send('paix', 'add', [docs.write('a')]);
      var over = false;
      docs.writes.send('paix', 'add', [
        docs.write('b'),
      ], whenOver: () => over = true);

      await docs.copy('paix', {'a': 1});
      expect(over, isFalse);

      await docs.copy('paix', {'a': 1, 'b': 1});
      expect(over, isTrue);
    });
  });

  group('after', () {
    test('should hold back a batch until what it comes after is '
        'done', () async {
      final kept = Completer<void>();
      docs.writes.send('paix', 'add', [docs.write('a')], after: kept.future);
      await pumpEventQueue();
      expect(docs.sent, isEmpty);

      kept.complete();
      await pumpEventQueue();

      expect(docs.sent, ['a']);
    });

    test('should hold back a later batch on the same document too', () async {
      final kept = Completer<void>();
      docs.writes.send('paix', 'add', [docs.write('a')], after: kept.future);
      docs.writes.send('paix', 'save', [docs.write('b', waits: false)]);
      await pumpEventQueue();
      expect(docs.sent, isEmpty);

      kept.complete();
      await pumpEventQueue();
      expect(docs.sent, ['a']);
      await docs.copy('paix', {'a': 1});

      expect(docs.sent, ['a', 'b']);
    });

    test('should wait for the batch before as well as for what it comes '
        'after', () async {
      docs.writes.send('paix', 'add', [docs.write('a')]);
      docs.writes.send('paix', 'add', [docs.write('b')], after: Future.value());
      await pumpEventQueue();
      expect(docs.sent, ['a']);

      await docs.copy('paix', {'a': 1});

      expect(docs.sent, ['a', 'b']);
    });
  });

  group('several batches', () {
    test('should hold back a batch until the one before on the same '
        'document is shown whole', () async {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);
      docs.writes.send('paix', 'save', [docs.write('c', waits: false)]);

      await docs.copy('paix', {'a': 1});
      expect(docs.sent, ['a', 'b']);

      await docs.copy('paix', {'a': 1, 'b': 1});
      expect(docs.sent, ['a', 'b', 'c']);
    });

    test('should not hold back a batch for another document', () {
      docs.writes.send('paix', 'add', [docs.write('a'), docs.write('b')]);

      docs.writes.send('lilas', 'save', [docs.write('c', waits: false)]);

      expect(docs.sent, ['a', 'c']);
    });

    test('should send a batch at once when the one before is over', () async {
      docs.writes.send('paix', 'add', [docs.write('a')]);
      await docs.copy('paix', {'a': 1});

      docs.writes.send('paix', 'save', [docs.write('b', waits: false)]);

      expect(docs.sent, ['a', 'b']);
    });

    test(
      'should keep a third batch behind the second when the first ends',
      () async {
        docs.writes.send('paix', 'add', [docs.write('a')]);
        docs.writes.send('paix', 'add', [docs.write('b')]);
        await docs.copy('paix', {'a': 1});
        expect(docs.sent, ['a', 'b']);

        docs.writes.send('paix', 'save', [docs.write('c', waits: false)]);
        await pumpEventQueue();

        expect(docs.sent, ['a', 'b']);
      },
    );
  });
}

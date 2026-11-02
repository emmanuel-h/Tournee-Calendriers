// The writes of this phone to the documents of one collection, kept in
// order per document (#70, PLAN §8.2 « Houses written in bulk »). Plain
// Dart: it is handed the writes and the phone's copy of each document, so
// its rules are tested without Firestore.
//
// Why it is needed: the Firestore plugin for Flutter does not keep the
// order of the calls made from Dart. On Android it runs each `set` or
// `update` on a thread of its own (`FlutterFirebaseFirestorePlugin`, a
// `cachedThreadPool`), so an `update` made just after a `set` can reach the
// Firestore SDK first. On a document that does not exist yet, that update
// is never applied to the phone's copy (offline) and refused « not found »
// (online): a new street kept only its first houses.
//
// The order cannot be had from the write's `Future`: it completes only when
// the server has the write, which offline is hours later. What the phone
// can see at once is its own copy: Firestore shows a write there the moment
// the SDK takes it, offline too, and a listener with metadata changes is
// told. So a write that must come after another is sent only once the copy
// shows the one before.
import 'dart:async';

/// One write of a document, and how to see it in the phone's copy.
final class OrderedWrite {
  const OrderedWrite(this.send, {this.isShownIn});

  /// Starts the write; its `Future` completes when the server has it.
  final Future<void> Function() send;

  /// Whether the phone's copy of the document (its data, null when it does
  /// not exist) shows this write. The next write waits for it; null when
  /// the next write may be sent at once (they touch different fields of a
  /// document that exists).
  final bool Function(Map<String, Object?>? copy)? isShownIn;
}

/// Sends the writes of each document in the order they were asked for.
///
/// A batch ([send]) goes after every batch asked for before on the same
/// document; within a batch, a write with [OrderedWrite.isShownIn] holds
/// back the writes after it until the phone's copy shows it. Nothing here
/// waits for the server: offline, a whole batch is in the phone's copy in a
/// moment (a few milliseconds per write).
///
/// A batch stops early, the rest of it never sent, when one of its writes
/// fails (refused) or the copy can no longer be read: what comes after
/// would be refused too. A write that is never shown (the document deleted
/// meanwhile) holds back the rest of its document for as long as the
/// phone's copy is followed.
final class OrderedWrites {
  // Private named parameters (`this._copyOf`): callers write them without
  // the underscore, `copyOf:`.
  OrderedWrites({required this._copyOf, required this._report});

  /// The phone's copy of the document [id], now and after each change.
  final Stream<Map<String, Object?>?> Function(String id) _copyOf;

  /// Takes each write sent, to tell its failure ([what] says which).
  final void Function(String what, Future<void> write) _report;

  /// The last batch of each document still running.
  final _running = <String, Future<void>>{};

  /// Sends [writes] to the document [id], in order, after the batches asked
  /// for before on it: at once when there is none.
  void send(String id, String what, List<OrderedWrite> writes) {
    final before = _running[id];
    final run = before == null
        ? _run(id, what, writes)
        : before.then((_) => _run(id, what, writes));
    _running[id] = run;
    // Forgotten when over, unless a later batch already took its place.
    unawaited(
      run.whenComplete(
        () => _running.removeWhere((_, last) => identical(last, run)),
      ),
    );
  }

  /// Sends [writes], each held back until the copy shows the one before
  /// that asks it; completes once the last is sent (and shown, when it
  /// asks it), or the batch stops.
  Future<void> _run(String id, String what, List<OrderedWrite> writes) {
    final done = Completer<void>();
    StreamSubscription<Map<String, Object?>?>? copies;
    var next = 0;
    bool Function(Map<String, Object?>?)? awaited;

    void finish() {
      if (done.isCompleted) return;
      awaited = null;
      unawaited(copies?.cancel());
      done.complete();
    }

    void sendOn() {
      while (next < writes.length) {
        final write = writes[next++];
        final sent = write.send();
        _report(what, sent);
        // A refused write stops the batch. Its error is told by [_report];
        // this handler only stops, and keeps the error from being
        // reported twice as « unhandled ».
        unawaited(sent.then<void>((_) {}, onError: (Object _) => finish()));
        if (write.isShownIn case final isShownIn?) {
          awaited = isShownIn;
          // Listened once per batch, from its first write to wait for:
          // each snapshot after that is checked against the write awaited
          // then.
          copies ??= _copyOf(id).listen(
            (copy) {
              if (awaited case final shown? when shown(copy)) {
                awaited = null;
                sendOn();
              }
            },
            onError: (Object _) => finish(),
            onDone: finish,
          );
          return;
        }
      }
      finish();
    }

    sendOn();
    return done.future;
  }
}

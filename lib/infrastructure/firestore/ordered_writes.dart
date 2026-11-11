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
/// fails (refused), the copy can no longer be read, or the copy says the
/// document is gone after it showed one of the batch's writes (deleted
/// meanwhile): what comes after would be refused too.
///
/// A write never shown (its document deleted before the write was taken)
/// would hold back the rest of its document, kept only in memory and lost
/// if the app is killed (#152). So no write is waited for longer than
/// [patience]: past it, the rest of the batch is sent at once and the wait
/// is logged.
final class OrderedWrites {
  // Private named parameters (`this._copyOf`): callers write them without
  // the underscore, `copyOf:`.
  OrderedWrites({
    required this._copyOf,
    required this._report,
    required this._log,
    this.patience = const Duration(seconds: 30),
    Timer Function(Duration, void Function())? startTimer,
  }) : _startTimer = startTimer ?? Timer.new;

  /// The longest wait for one write to show in the phone's copy. A local
  /// write shows in a few milliseconds, offline too: this only guards
  /// against a write that will never show.
  final Duration patience;

  /// The phone's copy of the document [id], now and after each change.
  final Stream<Map<String, Object?>?> Function(String id) _copyOf;

  /// Takes each write sent, to tell its failure ([what] says which).
  final void Function(String what, Future<void> write) _report;

  /// Tells a batch that did not end as planned (a debug log).
  final void Function(String message) _log;

  /// Starts the [patience] timer. `Timer.new` is the `Timer(duration,
  /// callback)` constructor passed as a function; tests give a timer they
  /// fire themselves, so no test waits for a real clock.
  final Timer Function(Duration, void Function()) _startTimer;

  /// The last batch of each document still running.
  final _running = <String, Future<void>>{};

  /// Sends [writes] to the document [id], in order, after the batches asked
  /// for before on it: at once when there is none.
  ///
  /// The batch also waits for [after], when given (the phone keeping a
  /// new street on its storage first, #104); it must not fail. Later
  /// batches on [id] wait for this one, so for [after] too.
  ///
  /// [whenOver] is called once the batch is over: its last write sent (and
  /// shown, when it asks it), or the batch stopped early. Every write it
  /// sent is then in the Firestore SDK, which keeps them across a restart.
  void send(
    String id,
    String what,
    List<OrderedWrite> writes, {
    Future<void>? after,
    void Function()? whenOver,
  }) {
    final before = switch ((_running[id], after)) {
      (null, null) => null,
      (final running?, null) => running,
      (null, final after?) => after,
      (final running?, final after?) => running.then((_) => after),
    };
    final run = before == null
        ? _run(id, what, writes)
        : before.then((_) => _run(id, what, writes));
    if (whenOver != null) unawaited(run.then((_) => whenOver()));
    _running[id] = run;
    // Forgotten when over, unless a later batch already took its place.
    unawaited(
      run.whenComplete(
        () => _running.removeWhere((_, last) => identical(last, run)),
      ),
    );
  }

  /// Sends [writes], each held back until the copy shows the one before
  /// that asks it (for [patience] at most); completes once the last is
  /// sent (and shown, when it asks it), or the batch stops.
  Future<void> _run(String id, String what, List<OrderedWrite> writes) {
    final done = Completer<void>();
    StreamSubscription<Map<String, Object?>?>? copies;
    Timer? waiting;
    var next = 0;
    // Whether the copy has shown a write of this batch: from then on the
    // document exists, so a copy without it means it was deleted. Before,
    // a missing copy only means the first write is not shown yet.
    var shownOnce = false;
    bool Function(Map<String, Object?>?)? awaited;

    void finish() {
      if (done.isCompleted) return;
      awaited = null;
      waiting?.cancel();
      unawaited(copies?.cancel());
      done.complete();
    }

    void sendNext() {
      final sent = writes[next++].send();
      _report(what, sent);
      // A refused write stops the batch. Its error is told by [_report];
      // this handler only stops, and keeps the error from being reported
      // twice as « unhandled ».
      unawaited(sent.then<void>((_) {}, onError: (Object _) => finish()));
    }

    // Time ran out for the write awaited: the rest goes to the Firestore
    // SDK now, which keeps it across a restart, rather than wait in memory.
    void sendTheRest() {
      _log(
        'Document $id ($what): write $next of ${writes.length} not shown '
        'after ${patience.inSeconds} s, the rest sent without waiting',
      );
      while (next < writes.length) {
        sendNext();
      }
      finish();
    }

    void sendOn() {
      while (next < writes.length) {
        final isShownIn = writes[next].isShownIn;
        sendNext();
        if (isShownIn != null) {
          awaited = isShownIn;
          waiting = _startTimer(patience, sendTheRest);
          // Listened once per batch, from its first write to wait for:
          // each snapshot after that is checked against the write awaited
          // then.
          copies ??= _copyOf(id).listen(
            (copy) {
              if (copy == null && shownOnce) {
                _log(
                  'Document $id ($what) gone while written: '
                  '${writes.length - next} writes not sent',
                );
                finish();
              } else if (awaited case final shown? when shown(copy)) {
                awaited = null;
                shownOnce = true;
                waiting?.cancel();
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

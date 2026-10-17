import 'dart:async';

/// A stream giving [read] of what [load] gives, once loaded, then again
/// after each event of [changes] that [concerns] it: how the street
/// adapters answer `watch`, `watchAll` and `watchDeleted` from their
/// memory.
///
/// Nothing starts before someone listens. A failure of [load] or of
/// [changes] reaches the listener. A listener that leaves stops the
/// updates and closes the stream, so a screen that goes away leaves
/// nothing running.
Stream<T> loadThenFollow<S, C, T>({
  required Future<S> Function() load,
  required Stream<C> changes,
  required bool Function(C change) concerns,
  required T Function(S loaded) read,
}) {
  // `late`: the callbacks below name the controller, which exists by the
  // time they run.
  late final StreamController<T> controller;
  StreamSubscription<C>? subscription;
  controller = StreamController<T>(
    onListen: () => unawaited(
      load().then((loaded) {
        // The listener may have left while waiting for the load.
        if (!controller.hasListener) return;
        controller.add(read(loaded));
        subscription = changes
            .where(concerns)
            .listen(
              (_) => controller.add(read(loaded)),
              onError: controller.addError,
            );
      }, onError: controller.addError),
    ),
    onCancel: () async {
      await subscription?.cancel();
      await controller.close();
    },
  );
  return controller.stream;
}

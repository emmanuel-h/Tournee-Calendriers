// A hand-written Schedule: keeps each callback instead of starting a timer,
// so a test runs it when it chooses (no real time passes).
import 'dart:async';

final class FakeSchedule {
  /// Every delay asked, in order.
  final delays = <Duration>[];

  /// The callbacks not cancelled, in order.
  final _pending = <_FakeTimer>[];

  /// How many callbacks wait.
  int get waiting => _pending.where((timer) => timer.isActive).length;

  Timer call(Duration delay, void Function() callback) {
    delays.add(delay);
    final timer = _FakeTimer(callback);
    _pending.add(timer);
    return timer;
  }

  /// Runs the callbacks still waiting, as if their time had come.
  void fire() {
    final due = [..._pending.where((timer) => timer.isActive)];
    _pending.clear();
    for (final timer in due) {
      timer.run();
    }
  }
}

final class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function() _callback;
  var _active = true;

  void run() {
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

import 'dart:io';

/// Decides what to do with an error nothing caught, as
/// `PlatformDispatcher.onError` asks: returns true when it is handled here.
///
/// A file the phone storage could not write (a full disk) is not a bug: the
/// storage throws it through the use case up to the screen's tap, where no
/// one can act on it (PLAN §7). The user is told with [onSaveFailed]. Any
/// other error is a bug, left to Flutter's default handling (logged).
bool handleUncaughtError(
  Object error, {
  required void Function() onSaveFailed,
}) {
  if (error is! FileSystemException) return false;
  onSaveFailed();
  return true;
}

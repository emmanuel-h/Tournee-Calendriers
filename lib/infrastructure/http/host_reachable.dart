import 'dart:async';
import 'dart:io';

/// Looks up the addresses of a host name: `InternetAddress.lookup` in the
/// app, a fake in tests.
typedef HostLookup = Future<List<InternetAddress>> Function(String host);

/// The server whose name is looked up to tell whether the phone is online
/// at start-up: Firestore's.
const firestoreHost = 'firestore.googleapis.com';

/// Whether the name [host] can be looked up within [timeout]: a cheap
/// sign that the phone has a network, read before Firestore starts (whose
/// own sign, `isFromCache`, only comes once it runs).
///
/// In airplane mode the lookup fails at once; with a poor signal it gives
/// up after [timeout], so a start-up waits at most that long. Any failure
/// counts as offline: the caller then keeps what it has.
Future<bool> hostReachable(
  String host, {
  HostLookup lookup = InternetAddress.lookup,
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    return (await lookup(host).timeout(timeout)).isNotEmpty;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  }
}

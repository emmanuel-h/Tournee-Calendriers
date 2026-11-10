import 'dart:io';

/// Whether [error], thrown by an HTTP call that got no answer, means the
/// phone has no usable network, rather than a service that is down.
///
/// Only a socket error says so: the name of the service could not be
/// looked up (airplane mode, no signal), or the operating system knows no
/// way to the network, or gave up waiting for it. Anything else reached a
/// server or at least a working network: a refused or reset connection, a
/// TLS failure, a connection closed mid-answer. The screens then say the
/// service is not answering instead of « Pas de réseau » (#137: a refused
/// connection had been told as no network while the WiFi worked).
///
/// `http` rethrows a socket error as a `ClientException` that also
/// implements [SocketException], so the same test sees both shapes.
bool meansNoNetwork(Object error) =>
    error is SocketException &&
    (error.message.startsWith('Failed host lookup') ||
        _noRouteErrors.contains(error.osError?.errorCode));

/// The `errno` values of a socket that found no way to the network:
/// network unreachable, no route to host, connection timed out. Android
/// uses Linux's numbers; iOS uses BSD's (a later iOS build reads them).
const _noRouteErrors = {
  101, 113, 110, // Android, Linux: ENETUNREACH, EHOSTUNREACH, ETIMEDOUT
  51, 65, 60, // iOS: ENETUNREACH, EHOSTUNREACH, ETIMEDOUT
};

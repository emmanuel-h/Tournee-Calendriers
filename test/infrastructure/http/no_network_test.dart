import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/http/no_network.dart';

void main() {
  // A socket error as `dart:io` raises it: a short message and the
  // operating system's error, whose number tells what happened.
  SocketException socketError(
    int errno, [
    String message = 'Connection failed',
  ]) => SocketException(message, osError: OSError('', errno));

  group('no network', () {
    final cases = <String, Object>{
      // Airplane mode or no signal: the name of the service cannot even be
      // looked up (Android says errno 7, Linux -2 or -3).
      'a failed host lookup': const SocketException(
        "Failed host lookup: 'geo.api.gouv.fr'",
        osError: OSError('No address associated with hostname', 7),
      ),
      'a failed host lookup without an OS error': const SocketException(
        "Failed host lookup: 'geo.api.gouv.fr'",
      ),
      'network unreachable (Android, Linux)': socketError(101),
      'no route to host (Android, Linux)': socketError(113),
      'connection timed out (Android, Linux)': socketError(110),
      'network unreachable (iOS)': socketError(51),
      'no route to host (iOS)': socketError(65),
      'connection timed out (iOS)': socketError(60),
    };
    cases.forEach((name, error) {
      test('should mean no network when given $name', () {
        expect(meansNoNetwork(error), isTrue);
      });
    });
  });

  group('a connection but no answer', () {
    final cases = <String, Object>{
      // What the phone saw on 2026-11-10: the server refused the
      // connection while the WiFi worked.
      'a refused connection': socketError(111, 'Connection refused'),
      'a connection reset': socketError(104),
      'a socket error without an OS error': const SocketException(
        'Connection failed',
      ),
      'a TLS failure': const HandshakeException('Connection reset'),
      'an http error without a socket': http.ClientException(
        'Connection closed before full header was received',
      ),
      'any other error': const FormatException('nonsense'),
    };
    cases.forEach((name, error) {
      test('should not mean no network when given $name', () {
        expect(meansNoNetwork(error), isFalse);
      });
    });

    test('should read the socket error that http wraps in its own', () async {
      // `http`'s IOClient rethrows a socket error as a ClientException that
      // is also a SocketException, the shape the phone sees. A port of this
      // computer nobody listens on refuses at once, without any network.
      final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = socket.port;
      await socket.close();
      final client = http.Client();
      addTearDown(client.close);

      final thrown = await client
          .get(Uri.parse('http://127.0.0.1:$port/'))
          .then<Object?>((_) => null, onError: (Object error) => error);

      expect(thrown, isA<http.ClientException>());
      expect(thrown, isA<SocketException>());
      expect(meansNoNetwork(thrown!), isFalse);
    });
  });
}

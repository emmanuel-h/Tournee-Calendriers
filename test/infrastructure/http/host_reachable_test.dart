import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/http/host_reachable.dart';

void main() {
  test('should look up Firestore\'s server', () {
    expect(firestoreHost, 'firestore.googleapis.com');
  });

  test('should say reachable when the name has an address', () async {
    final asked = <String>[];

    final reachable = await hostReachable(
      'example.org',
      lookup: (host) async {
        asked.add(host);
        return [InternetAddress('192.0.2.1')];
      },
    );

    expect(reachable, isTrue);
    expect(asked, ['example.org']);
  });

  test('should say unreachable when the name has no address', () async {
    expect(
      await hostReachable('example.org', lookup: (_) async => const []),
      isFalse,
    );
  });

  test('should say unreachable when the lookup fails (airplane '
      'mode)', () async {
    expect(
      await hostReachable(
        'example.org',
        lookup: (_) async =>
            throw const SocketException('Failed host lookup: example.org'),
      ),
      isFalse,
    );
  });

  test('should say unreachable when the lookup takes too long', () async {
    final never = Completer<List<InternetAddress>>();

    expect(
      await hostReachable(
        'example.org',
        lookup: (_) => never.future,
        timeout: Duration.zero,
      ),
      isFalse,
    );
  });
}

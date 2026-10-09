// The small rules the Firestore adapters share.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tournee_calendriers/infrastructure/firestore/firestore_layout.dart';

FirebaseException firestoreError(String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('isNoNetwork', () {
    test('should be true when the server is out of reach', () {
      expect(isNoNetwork(firestoreError('unavailable')), isTrue);
    });

    test('should be true when the server did not answer in time', () {
      expect(isNoNetwork(firestoreError('deadline-exceeded')), isTrue);
    });

    test('should be false for a refusal of the server', () {
      expect(isNoNetwork(firestoreError('permission-denied')), isFalse);
    });
  });

  group('isNoLongerReadable', () {
    test('should be true when the server refuses the read', () {
      expect(isNoLongerReadable(firestoreError('permission-denied')), isTrue);
    });

    test('should be false for another failure of the server', () {
      expect(isNoLongerReadable(firestoreError('unavailable')), isFalse);
    });

    test('should be false for a failure that is not the server', () {
      expect(
        isNoLongerReadable(const FormatException('permission-denied')),
        isFalse,
      );
    });
  });
}

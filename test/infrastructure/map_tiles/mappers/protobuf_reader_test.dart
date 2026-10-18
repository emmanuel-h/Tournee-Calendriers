import 'package:test/test.dart';
import 'package:tournee_calendriers/infrastructure/map_tiles/mappers/protobuf_reader.dart';

void main() {
  group('readVarint', () {
    test('should read a number of one byte', () {
      expect(ProtobufReader([0x7f]).readVarint(), 127);
    });

    test('should read a number of several bytes, low bits first', () {
      // 300 = 0b10_0101100: 0xAC (101100 with the « more » bit), then 0x02.
      expect(ProtobufReader([0xac, 0x02]).readVarint(), 300);
    });

    test('should read a number of ten bytes', () {
      final reader = ProtobufReader([...List.filled(9, 0xff), 0x01]);

      expect(reader.readVarint(), -1);
      expect(reader.isAtEnd, isTrue);
    });

    test('should refuse a number longer than ten bytes', () {
      expect(
        () => ProtobufReader([...List.filled(10, 0xff), 0x01]).readVarint(),
        throwsFormatException,
      );
    });

    test('should refuse a number cut short', () {
      expect(() => ProtobufReader([0xac]).readVarint(), throwsFormatException);
    });
  });

  test('should read a key as its field number and wire type', () {
    // Field 3, wire type 2: 3 << 3 | 2 = 26.
    final key = ProtobufReader([26]).readKey();

    expect(key.field, 3);
    expect(key.wireType, 2);
  });

  group('readString', () {
    test('should read a UTF-8 text', () {
      final reader = ProtobufReader([5, 0x52, 0x75, 0x65, 0xc3, 0xa9, 9]);

      expect(reader.readString(), 'Rueé');
      expect(reader.readVarint(), 9);
    });

    test('should refuse bytes that are not UTF-8', () {
      expect(
        () => ProtobufReader([1, 0xff]).readString(),
        throwsFormatException,
      );
    });

    test('should refuse a text longer than the message', () {
      expect(
        () => ProtobufReader([5, 0x52]).readString(),
        throwsFormatException,
      );
    });
  });

  test('should read a nested message up to its end only', () {
    final reader = ProtobufReader([2, 0x01, 0x02, 0x03]);

    final message = reader.readMessage();

    expect(message.readVarint(), 1);
    expect(message.readVarint(), 2);
    expect(message.isAtEnd, isTrue);
    expect(reader.readVarint(), 3);
  });

  group('readVarints', () {
    test('should read a packed list', () {
      final into = <int>[9];

      ProtobufReader([3, 0x01, 0xac, 0x02]).readVarints(2, into);

      expect(into, [9, 1, 300]);
    });

    test('should read a single number', () {
      final into = <int>[9];

      ProtobufReader([0x05]).readVarints(0, into);

      expect(into, [9, 5]);
    });

    test('should refuse another wire type', () {
      expect(
        () => ProtobufReader([1, 0, 0, 0]).readVarints(5, []),
        throwsFormatException,
      );
    });
  });

  group('skip', () {
    test('should step over a varint', () {
      final reader = ProtobufReader([0xac, 0x02, 7])..skip(0);

      expect(reader.readVarint(), 7);
    });

    test('should step over eight bytes', () {
      final reader = ProtobufReader([...List.filled(8, 0xff), 7])..skip(1);

      expect(reader.readVarint(), 7);
    });

    test('should step over a length and its bytes', () {
      final reader = ProtobufReader([2, 0xff, 0xff, 7])..skip(2);

      expect(reader.readVarint(), 7);
    });

    test('should step over four bytes', () {
      final reader = ProtobufReader([0xff, 0xff, 0xff, 0xff, 7])..skip(5);

      expect(reader.readVarint(), 7);
    });

    test('should refuse an unknown wire type', () {
      expect(() => ProtobufReader([7]).skip(3), throwsFormatException);
    });

    test('should refuse eight bytes past the end', () {
      expect(
        () => ProtobufReader(List.filled(7, 0)).skip(1),
        throwsFormatException,
      );
    });

    test('should refuse a negative length', () {
      expect(
        () => ProtobufReader([...List.filled(9, 0xff), 0x01]).skip(2),
        throwsFormatException,
      );
    });
  });

  test('should stop at the end given', () {
    final reader = ProtobufReader([1, 2, 3], start: 1, end: 2);

    expect(reader.readVarint(), 2);
    expect(reader.isAtEnd, isTrue);
    expect(reader.readVarint, throwsFormatException);
  });

  test('should decode zigzag numbers', () {
    expect([0, 1, 2, 3, 4, 4294967294, 4294967295].map(zigzagDecode), [
      0,
      -1,
      1,
      -2,
      2,
      2147483647,
      -2147483648,
    ]);
  });
}

// Reads Protocol Buffers ("protobuf"), the binary format of the map's
// vector tiles, by hand: the tiles need only a handful of its rules, and a
// generated reader would need code generation (protoc), which the project
// does not use.
//
// A protobuf message is a run of fields. Each field starts with a *key*, a
// varint holding the field's number and its *wire type* (how its value is
// written): 0 a varint, 1 eight bytes, 2 a length then that many bytes (a
// text, a nested message, or a packed list of varints), 5 four bytes. A
// *varint* writes a whole number 7 bits a byte, low bits first; the top bit
// of each byte says another byte follows.
import 'dart:convert';

/// The wire type of a varint field.
const varintWireType = 0;

/// The wire type of a field written as a length and that many bytes.
const lengthDelimitedWireType = 2;

/// Reads one protobuf message from [bytes], field after field.
///
/// Every read throws a [FormatException] when the bytes end too soon or
/// break the format: a damaged tile is never half read.
final class ProtobufReader {
  /// A reader over [bytes], from [start] to [end] (the whole list by
  /// default).
  ProtobufReader(this._bytes, {int start = 0, int? end})
    : _position = start,
      _end = end ?? _bytes.length;

  final List<int> _bytes;
  int _position;
  final int _end;

  /// Whether every field has been read.
  bool get isAtEnd => _position >= _end;

  /// The key of the next field: its number and its wire type.
  ({int field, int wireType}) readKey() {
    final key = readVarint();
    // The 3 low bits are the wire type, the others the field number.
    return (field: key >> 3, wireType: key & 0x7);
  }

  /// A varint: a whole number of up to 64 bits.
  int readVarint() {
    var value = 0;
    // 10 bytes of 7 bits hold 64 bits.
    for (var shift = 0; shift < 70; shift += 7) {
      final byte = _byte();
      value |= (byte & 0x7f) << shift;
      if (byte & 0x80 == 0) return value;
    }
    throw const FormatException('Varint longer than 10 bytes');
  }

  /// A length-delimited field read as a nested message.
  ProtobufReader readMessage() {
    final (start, end) = _lengthDelimited();
    return ProtobufReader(_bytes, start: start, end: end);
  }

  /// A length-delimited field read as a UTF-8 text.
  String readString() {
    final (start, end) = _lengthDelimited();
    // `utf8.decode` throws a FormatException on bytes that are not UTF-8.
    return utf8.decode(_bytes.sublist(start, end));
  }

  /// The varints of a repeated field, added to [into]: a packed list
  /// (one length-delimited field) or a single varint, as protobuf allows
  /// either for a list of numbers.
  void readVarints(int wireType, List<int> into) {
    if (wireType == varintWireType) {
      into.add(readVarint());
      return;
    }
    if (wireType != lengthDelimitedWireType) {
      throw FormatException('Not a list of numbers: wire type $wireType');
    }
    final packed = readMessage();
    while (!packed.isAtEnd) {
      into.add(packed.readVarint());
    }
  }

  /// Steps over the value of a field this reader does not need.
  void skip(int wireType) {
    switch (wireType) {
      case varintWireType:
        readVarint();
      case 1:
        _advance(8);
      case lengthDelimitedWireType:
        _lengthDelimited();
      case 5:
        _advance(4);
      default:
        throw FormatException('Unknown wire type $wireType');
    }
  }

  /// The start and end of a length-delimited field's bytes, stepped over.
  (int, int) _lengthDelimited() {
    final length = readVarint();
    final start = _position;
    _advance(length);
    return (start, _position);
  }

  void _advance(int count) {
    // A negative length is a varint of 64 bits, read as a negative int.
    if (count < 0 || _position + count > _end) {
      throw const FormatException('Field past the end of the message');
    }
    _position += count;
  }

  int _byte() {
    if (_position >= _end) {
      throw const FormatException('Message cut short');
    }
    return _bytes[_position++];
  }
}

/// The signed number a « zigzag » varint stands for: 0, -1, 1, -2, 2… are
/// written 0, 1, 2, 3, 4…, so a small negative number stays short.
int zigzagDecode(int value) => (value >> 1) ^ -(value & 1);

import 'dart:convert';

import 'package:test/test.dart';
import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/infrastructure/notifications/mappers/reminder_payload.dart';

import '../../../domain/come_back/come_back_fixtures.dart';
import '../../../support/street_fixtures.dart';

void main() {
  final house = OpenComeBackPlace(
    ComeBackPlace(street: nationaleId, number: n('12bis')),
  );
  final door = OpenComeBackPlace(
    ComeBackPlace(
      street: pasteurId,
      number: n('8'),
      door: DwellingKey(escA, 5, d('51')),
    ),
  );

  test('should write the list', () {
    expect(jsonDecode(reminderPayload(const OpenComeBackList())), {
      'open': 'list',
    });
  });

  test('should write a house and a door', () {
    expect(jsonDecode(reminderPayload(house)), {
      'open': 'place',
      'street': 'nationale',
      'number': '12bis',
      'door': null,
    });
    expect(jsonDecode(reminderPayload(door)), {
      'open': 'place',
      'street': 'pasteur',
      'number': '8',
      'door': 'A5-51',
    });
  });

  test('should read back what it wrote', () {
    for (final target in [const OpenComeBackList(), house, door]) {
      expect(reminderTargetFrom(reminderPayload(target)), target);
    }
  });

  final unreadable = <String, String?>{
    'no payload': null,
    'text that is not JSON': 'list',
    'another kind': '{"open": "street"}',
    'a blank street':
        '{"open": "place", "street": " ", "number": "12", "door": null}',
    'a wrong number':
        '{"open": "place", "street": "s", "number": "bis", "door": null}',
    'a wrong door':
        '{"open": "place", "street": "s", "number": "8", "door": "51"}',
    'no door field': '{"open": "place", "street": "s", "number": "8"}',
  };
  unreadable.forEach((what, payload) {
    test('should lead nowhere from $what', () {
      expect(reminderTargetFrom(payload), isNull);
    });
  });
}

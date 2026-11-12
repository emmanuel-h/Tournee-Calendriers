// Translation between where a reminder leads (PLAN §5.17) and the text
// Android keeps with its notification, handed back when it is tapped.
// Pure functions: no plugin here, so they are tested alone.
//
// The payload, JSON:
//
//   { open: "list" }
//   { open: "place", street: "<id>", number: "12bis", door: "A5-51" | null }
//
// A reminder scheduled by an older version may still be tapped after an
// update: a payload that cannot be read leads nowhere, it never fails.
import 'dart:convert';

import 'package:tournee_calendriers/domain/come_back/come_back_entry.dart';
import 'package:tournee_calendriers/domain/come_back/reminder.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';

/// The payload of a reminder leading to [target].
String reminderPayload(ReminderTarget target) => jsonEncode(switch (target) {
  OpenComeBackList() => {'open': 'list'},
  OpenComeBackPlace(:final place) => {
    'open': 'place',
    'street': place.street.value,
    'number': place.number.label,
    'door': place.door?.id,
  },
});

/// Where [payload] leads; null when it is missing or not one this code
/// wrote.
ReminderTarget? reminderTargetFrom(String? payload) {
  if (payload == null) return null;
  final Object? json;
  try {
    json = jsonDecode(payload);
  } on FormatException {
    return null;
  }
  return switch (json) {
    {'open': 'list'} => const OpenComeBackList(),
    {
      'open': 'place',
      'street': final String street,
      'number': final String number,
      'door': final String? door,
    }
        when street.trim().isNotEmpty =>
      _placeTarget(StreetId(street), number, door),
    _ => null,
  };
}

ReminderTarget? _placeTarget(StreetId street, String number, String? door) {
  final DwellingKey? key;
  if (door == null) {
    key = null;
  } else {
    key = DwellingKey.parse(door);
    if (key == null) return null;
  }
  return switch (HouseNumber.parse(number)) {
    Ok(:final value) => OpenComeBackPlace(
      ComeBackPlace(street: street, number: value, door: key),
    ),
    Err() => null,
  };
}

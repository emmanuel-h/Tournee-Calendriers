// The houses of a new street, and the numbers added to one, written a few
// at a time (#70, PLAN §8.2). Pure functions, tested alone.
//
// Why: the security rules check each house a write adds, field by field
// (no `note`, `by` = the caller, a status among the four…). Their language
// has no loops, so the check is written out once per house, and a request
// may evaluate at most 1 000 expressions: only [housesPerWrite] houses fit
// in one write. A new street is therefore its document with its first
// houses, then updates of the next ones, in order.
//
// The order is not kept for free: the Firestore plugin may hand two calls
// made back to back to the SDK the other way round, and an update before
// its document is lost. So each write goes only once the phone's copy
// holds the houses of the one before ([holdsHouses], ordered_writes.dart).
// Once in the SDK, the writes keep their order to the server, offline too
// (its queue survives a restart). Until the last one arrives, a teammate
// may see the street with part of its houses: accepted (decided
// 2026-11-02, #70).
import 'package:cloud_firestore/cloud_firestore.dart' show FieldPath;
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/infrastructure/firestore/mappers/street_document_mapper.dart';

/// The most houses one write adds: `housesPerWrite()` in
/// `firebase/firestore.rules`, which explains the figure. A test checks
/// that both say the same.
const housesPerWrite = 2;

/// The writes storing the new [street], in the order they are sent: its
/// [document] (for a `set`) with its first [housesPerWrite] houses, then
/// the [updates] adding the next ones, [housesPerWrite] at most each.
///
/// The houses come in the order of [streetToDocument]: those shown, in
/// the street's order, then those in the Corbeille.
({Map<String, Object?> document, List<Map<FieldPath, Object?>> updates})
newStreetWrites(Street street) {
  final whole = streetToDocument(street);
  final houses = (whole['houses']! as Map<String, Object?>).entries;
  return (
    document: {
      ...whole,
      'houses': Map.fromEntries(houses.take(housesPerWrite)),
    },
    updates: addedHouseUpdates(Map.fromEntries(houses.skip(housesPerWrite))),
  );
}

/// The updates adding the house [entries] (label → entry) to a street,
/// [housesPerWrite] at most each, in the order of [entries]. None when
/// there is no entry.
List<Map<FieldPath, Object?>> addedHouseUpdates(Map<String, Object?> entries) {
  final all = entries.entries.toList();
  return [
    for (var start = 0; start < all.length; start += housesPerWrite)
      {
        for (final MapEntry(:key, :value)
            in all.skip(start).take(housesPerWrite))
          FieldPath(['houses', key]): value,
      },
  ];
}

/// Whether the stored [document] (null when there is none) holds a house
/// under each of [labels]: the phone's copy shows the write that added
/// them, and the next may go.
bool holdsHouses(Map<String, Object?>? document, Iterable<String> labels) {
  if (document?['houses'] case final Map<Object?, Object?> houses) {
    return labels.every(houses.containsKey);
  }
  return false;
}

/// The labels of the houses an update of [addedHouseUpdates] adds.
Iterable<String> addedLabels(Map<FieldPath, Object?> update) =>
    update.keys.map((path) => path.components[1]);

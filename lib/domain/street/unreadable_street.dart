import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';

/// A street of the secteur whose stored data cannot be read (PLAN §5.16,
/// #149): a write of an older or buggy app, or one the security rules only
/// counted, left a value the domain refuses. It is not a `Street`: nothing
/// of it can be trusted but its [id] and, when that field alone reads, its
/// [name].
///
/// Accueil lists it as a row of its own (« ⚠ Rue Pasteur · Illisible »)
/// rather than leaving it out, so the team sees it and an admin can delete
/// it, then add it again. It is never on the map nor in the totals.
final class UnreadableStreet {
  const UnreadableStreet({required this.id, this.name});

  /// The street's id, the document's: what deleting it names.
  final StreetId id;

  /// Its name when the stored name reads as one; null when even that
  /// cannot be read (« Rue illisible »).
  final StreetName? name;

  @override
  bool operator ==(Object other) =>
      other is UnreadableStreet && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'UnreadableStreet(${id.value}, ${name?.text})';
}

import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// The list of streets of the start screen (each with its progress, read
/// from `Street.progress`), now and after each change. Works offline.
///
/// Streets in the Corbeille are left out.
final class ObserveStreets {
  const ObserveStreets(this._streets);

  final StreetRepository _streets;

  /// The streets in alphabetical order of their names, ignoring case (two
  /// streets of the same name, in two communes, by id). Accents are compared
  /// as plain characters: « Église » comes after « Z ».
  Stream<List<Street>> call() => _streets.watchAll().map(
    (streets) => List.unmodifiable(streets.toList()..sort(_byName)),
  );

  static int _byName(Street a, Street b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.value.compareTo(b.id.value);
  }
}

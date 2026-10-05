import 'package:tournee_calendriers/domain/shared/french_text.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_repository.dart';

/// The list of streets of the start screen (each with its progress, read
/// from `Street.progress`), now and after each change. Works offline.
///
/// Streets in the Corbeille are left out.
final class ObserveStreets {
  const ObserveStreets(this._streets);

  final StreetRepository _streets;

  /// The streets in alphabetical order of their names, the French way:
  /// case and accents ignored, so « Allée Émile Zola » comes before « Allée
  /// Fleurie » (see `compareFrench`). Two streets of the same name, in two
  /// communes, by id.
  Stream<List<Street>> call() => _streets.watchAll().map(
    (streets) => List.unmodifiable(streets.toList()..sort(_byName)),
  );

  static int _byName(Street a, Street b) {
    final byName = compareFrench(a.name.text, b.name.text);
    return byName != 0 ? byName : a.id.value.compareTo(b.id.value);
  }
}

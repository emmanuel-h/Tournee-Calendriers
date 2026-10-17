import 'package:tournee_calendriers/domain/shared/commune.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/presentation/edit_street/add_numbers_state.dart';

export 'package:tournee_calendriers/presentation/edit_street/add_numbers_state.dart'
    show NothingTyped, NumbersPreview, NumbersPreviewed, NumbersRefused;

/// What « Rue à la main » shows (PLAN §5.5, Manual mockup): the form of a
/// street the map does not have, with the preview of its numbers. Works
/// offline. Immutable: the notifier replaces it as a whole.
final class ManualStreetState {
  ManualStreetState({
    required List<Commune> communes,
    required this.commune,
    required this.sides,
    required this.nameProblem,
    required this.preview,
    required this.adding,
    required bool nameIsValid,
  }) : communes = List.unmodifiable(communes),
       canAdd =
           nameIsValid &&
           commune != null &&
           preview is NumbersPreviewed &&
           !adding;

  /// The communes the street may be in: the tournée's, else those of its
  /// streets. Empty for a tournée with neither: the commune is then
  /// searched (network), as on the « Liste » tab. Read-only.
  final List<Commune> communes;

  /// The commune chosen: the first of [communes] until another is; null
  /// while none is known.
  final Commune? commune;

  /// « Les deux | Impairs | Pairs ».
  final Sides sides;

  /// Why the name typed cannot be kept, once it is too long; a blank name
  /// only keeps « Ajouter la rue » disabled.
  final StreetNameFailure? nameProblem;

  /// « Aperçu · 59 numéros », or the item that is wrong.
  final NumbersPreview preview;

  /// The street is being stored (a moment).
  final bool adding;

  /// « Ajouter la rue » is enabled: a name, a commune and at least one
  /// number.
  final bool canAdd;
}

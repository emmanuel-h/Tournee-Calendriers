import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/domain/street/street_part_choice.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/street_part/other_sectors.dart';
import 'package:tournee_calendriers/presentation/street_part/street_part_state.dart';

/// The state of one opening of « Partie de la rue » (`family`: one per
/// request; `autoDispose`: forgotten when the screen goes, ✕ or back
/// leaving nothing behind).
final streetPartProvider = NotifierProvider.autoDispose
    .family<StreetPartNotifier, StreetPartView, StreetPartRequest>(
      StreetPartNotifier.new,
    );

/// « Partie de la rue » (PLAN §5.15): the side shown, the marks moved, the
/// quick buttons and the « Du n° / Au n° » fields change the part being
/// chosen ([StreetPartChoice]); « Valider » gives back [chosen]. Nothing is
/// stored here, and nothing needs the network: the numbers came with the
/// request.
///
/// For a street from the BAN, what the other secteurs hold is read from
/// the shared index in the background (`ReadOtherSectorParts`, PLAN §5.15
/// « Other secteurs »): once it comes, their stretches are hatched, the
/// numbers shared drawn amber and named above « Valider ». Until then,
/// and when it cannot be read, nothing of it shows and nothing waits.
final class StreetPartNotifier extends Notifier<StreetPartView> {
  StreetPartNotifier(this.request);

  final StreetPartRequest request;

  late StreetPartChoice _choice;

  @override
  StreetPartView build() {
    _choice = request.choice;
    if (request.banId case final banId?) unawaited(_readOthers(banId));
    return _view();
  }

  Future<void> _readOthers(BanStreetId banId) async {
    final others = await ref.read(readOtherSectorPartsProvider)(banId);
    if (!ref.mounted || others.isEmpty) return;
    _show(_choice.withOthers(others));
  }

  /// The part chosen, for « Valider ».
  StreetPart get chosen => _choice.part;

  /// « Les deux | Impairs | Pairs ».
  void chooseSide(Sides side) => _show(_choice.withSide(side));

  /// A mark dragged to the [gap]-th place of the map's `gaps`.
  void moveMark(PartMark mark, int gap) => _show(_choice.withMark(mark, gap));

  /// « Toute la rue », « Tous les impairs », « Tous les pairs ».
  void holdAll() => _show(_choice.holdingAll());

  /// « Rien », « Aucun impair », « Aucun pair ».
  void holdNothing() => _show(_choice.holdingNothing());

  /// « Du n° » and « Au n° » as typed: digits, or blank for the side's
  /// first or last number.
  void typeBounds({required String from, required String to}) =>
      _show(_choice.withBounds(from: _numberIn(from), to: _numberIn(to)));

  void _show(StreetPartChoice choice) {
    _choice = choice;
    state = _view();
  }

  StreetPartView _view() => StreetPartView.of(
    request.streetName,
    _choice,
    // `ref.read`: the open secteur's centre, read when the view is made;
    // the screen does not outlive a switch of secteur.
    overlaps: switch (_choice.overlaps) {
      [] => const [],
      final overlaps => OverlapLine.of(
        overlaps,
        ref.read(currentSectorProvider)?.centre,
      ),
    },
  );

  /// The number typed in [text]; null when blank or not a number.
  static int? _numberIn(String text) => int.tryParse(text.trim());
}

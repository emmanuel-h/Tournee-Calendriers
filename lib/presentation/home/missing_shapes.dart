import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/ports/clock.dart';
import 'package:tournee_calendriers/application/use_cases/fill_street_shape.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/street.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// The one [MissingShapes] of the app. A plain `Provider`, not
/// `autoDispose`: it lives as long as the app, so what it tried is
/// remembered for the session, whichever screen shows. It is built again,
/// with nothing tried, when another tournée opens (its use case follows
/// the open tournée's streets).
final missingShapesProvider = Provider<MissingShapes>(
  (ref) => MissingShapes(
    ref.watch(fillStreetShapeProvider),
    ref.watch(clockProvider),
  ),
);

/// Gives the open tournée's streets without a line on the map the road the
/// map draws for them (PLAN §5.3, #92): Accueil hands it the streets each
/// time they change, and it asks for the shapes in the background.
///
/// Gently, since the map is a public service and the phone may be offline:
/// - each street is asked **once a session**, whatever the answer (a road
///   found, or none of that name);
/// - **one street at a time**: streets handed while it works wait for the
///   current street to be done;
/// - **a failure** (no network, the service down) stops the run and puts
///   the next one off for [retryDelay]; the street that failed is asked
///   again then.
///
/// Nothing here is on the marking path: offline, it fails and waits.
final class MissingShapes {
  MissingShapes(this._fill, this._clock);

  /// How long after a failure the next run waits.
  static const retryDelay = Duration(minutes: 2);

  final FillStreetShape _fill;
  final Clock _clock;

  final _tried = <StreetId>{};
  var _running = false;

  /// The streets handed while a run was going, for the next run.
  List<Street>? _waiting;

  /// No run before this time, after a failure.
  DateTime? _pausedUntil;

  /// Fills, one after the other, the shapes of the [streets] that need one
  /// (`Street.needsShape`) and were not asked yet. Returns once the run is
  /// over; a call made while a run goes returns at once, its streets taken
  /// by that run when it is done with its own.
  Future<void> fillAmong(Iterable<Street> streets) async {
    _waiting = streets.toList();
    if (_running) return;
    _running = true;
    try {
      // Round again while streets were handed during the run.
      for (var batch = _waiting; batch != null; batch = _waiting) {
        _waiting = null;
        if (_pausedUntil case final until? when _clock.now().isBefore(until)) {
          return;
        }
        await _run(batch);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _run(List<Street> streets) async {
    for (final street in streets) {
      // `add` is false when the street was asked already.
      if (!street.needsShape || !_tried.add(street.id)) continue;
      if (await _fill(street.id) case Err()) {
        _tried.remove(street.id);
        // The streets handed meanwhile wait for the next run too: the
        // pause stops the loop of [fillAmong].
        _pausedUntil = _clock.now().add(retryDelay);
        return;
      }
    }
  }
}

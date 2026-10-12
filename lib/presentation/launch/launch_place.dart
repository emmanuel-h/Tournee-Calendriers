import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/application/use_cases/choose_start_point.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_id.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// Which screen the app opens on (PLAN §4): the screens' own copy of the
/// application's `StartPoint`, since `ui/` may not name the application
/// layer. `sealed`: the router handles each case.
sealed class LaunchPlace {
  const LaunchPlace();
}

/// « Mes rues »: the open tournée's streets, or the phone's own.
final class LaunchOnStreets extends LaunchPlace {
  const LaunchOnStreets();
}

/// « Bienvenue ».
final class LaunchOnWelcome extends LaunchPlace {
  const LaunchOnWelcome();
}

/// « Demande envoyée » for the request to join [tournee].
final class LaunchOnRequest extends LaunchPlace {
  const LaunchOnRequest(this.tournee);

  final TourneeId tournee;

  @override
  bool operator ==(Object other) =>
      other is LaunchOnRequest && other.tournee == tournee;

  @override
  int get hashCode => tournee.hashCode;

  @override
  String toString() => 'LaunchOnRequest(${tournee.value})';
}

/// The screen showing [point].
LaunchPlace launchPlaceOf(StartPoint point) => switch (point) {
  StartOnStreets() => const LaunchOnStreets(),
  StartOnWelcome() => const LaunchOnWelcome(),
  StartOnRequest(:final request) => LaunchOnRequest(request.id),
};

/// Where the app opens, decided once at launch from what the phone holds,
/// without the network (`ChooseStartPoint`).
///
/// A `FutureProvider` holds the answer of an `async` function: loading
/// first (the phone's streets are read from the disk), then the place.
/// Not `autoDispose`: it is read once, when the app starts, and kept.
final launchPlaceProvider = FutureProvider<LaunchPlace>(
  (ref) async => launchPlaceOf(await ref.read(chooseStartPointProvider)()),
);

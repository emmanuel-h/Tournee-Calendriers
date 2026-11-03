import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// « RUES (38) » of the Secteur screen (PLAN §5.14): how many streets the
/// open secteur has outside the Corbeille, the ones Accueil lists. Read
/// from the phone's copy, so it shows offline too.
///
/// A `StreamProvider` holds the latest value of a stream as an
/// `AsyncValue`: `.value` is null until the first count arrives.
/// `autoDispose`: the streets are followed only while Secteur shows.
final sectorStreetCountProvider = StreamProvider.autoDispose<int>(
  (ref) => ref.watch(observeStreetsProvider)().map((streets) => streets.length),
);

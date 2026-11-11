import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/dependencies.dart';

/// Sends to their secteur, while the app runs, the validated tournées
/// waiting on the phone (`SendUnsentRounds`, PLAN §5.16, #143). Nothing to
/// show: Collecte tells where each one stands.
///
/// A plain `Provider` the composition root keeps alive (`ref.listen`):
/// built once at start-up, it sends what was waiting since the last run,
/// then each tournée validated or tried again. Disposed with the app, it
/// stops following them.
final unsentRoundsSenderProvider = Provider<void>((ref) {
  final sending = ref.watch(sendUnsentRoundsProvider)();
  ref.onDispose(() => unawaited(sending.cancel()));
});

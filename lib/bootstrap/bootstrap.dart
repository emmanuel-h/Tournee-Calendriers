/// Composition root: the only layer that sees every other one. Later tasks
/// initialise Firebase here and bind each port to its adapter with providers.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/ui/app.dart';

/// Starts the app.
///
/// `ProviderScope` is the Riverpod container: every provider's state lives in
/// it, and tests replace a provider (a port, for instance) with a fake by
/// passing `overrides` to their own `ProviderScope`.
void bootstrap() => runApp(const ProviderScope(child: TourneeApp()));

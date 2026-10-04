/// Flutter widgets: screens, theme, components and the map. Widgets read view
/// states from `presentation/` and send intents back; no business logic.
library;

import 'package:flutter/material.dart';

/// The app's French name, shown in the title bar and the task switcher.
///
/// It moves to `app_fr.arb` when localisation arrives (T0.2).
const _appTitle = 'Tournée des calendriers';

/// Root widget: for now a blank screen with the app's title.
///
/// A `StatelessWidget` has no mutable state of its own; it is rebuilt from its
/// constructor arguments, which suits a root that only configures
/// `MaterialApp`.
final class TourneeApp extends StatelessWidget {
  const TourneeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: _appTitle,
    debugShowCheckedModeBanner: false,
    home: Scaffold(appBar: AppBar(title: const Text(_appTitle))),
  );
}

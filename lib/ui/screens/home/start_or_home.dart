import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/start/start_screen.dart';

/// The start screen (`/`): Accueil, the map and its « Mes rues » panel,
/// while a tournée is open (PLAN §5.3); the phone's own streets of M1
/// (« Mes rues », §5.0) when none is.
///
/// `select`: only opening or closing a tournée switches the screen;
/// switching from one tournée to another keeps Accueil, which follows it.
final class StartOrHome extends ConsumerWidget {
  const StartOrHome({super.key, required this.showGallery});

  /// Debug builds: an app-bar action opens the component gallery.
  final bool showGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(currentTourneeProvider.select((tournee) => tournee != null))
      ? HomeScreen(showGallery: showGallery)
      : StartScreen(showGallery: showGallery);
}

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/ui/screens/home/home_screen.dart';
import 'package:tournee_calendriers/ui/screens/home/no_sector_screen.dart';

/// The start screen (`/`): Accueil, the map and its « Rues » panel,
/// while a secteur is open (PLAN §5.3); « Aucun secteur ouvert » (§5.0)
/// when none is.
///
/// `select`: only opening or closing a secteur switches the screen;
/// switching from one secteur to another keeps Accueil, which follows it.
final class StartOrHome extends ConsumerWidget {
  const StartOrHome({super.key, required this.showGallery});

  /// Debug builds: an app-bar action opens the component gallery.
  final bool showGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(currentSectorProvider.select((sector) => sector != null))
      ? HomeScreen(showGallery: showGallery)
      : NoSectorScreen(showGallery: showGallery);
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/sector/sector_summary.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/my_sectors_sheet.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/sector_title_button.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The top bar of the start screen, Accueil's (PLAN §5.3, Home mockup)
/// with a secteur open or none (§5.0, NoSector mockup): the open secteur
/// (« Secteur 49 · 2026 ▾ » over its centre, with a dot while a request
/// waits) opens Secteur (§5.14, #135), ⚙ opens Paramètres. With no secteur
/// open, the app's name stays and opens « Mes secteurs ».
///
/// A `Scaffold` asks its app bar for its height before building it: hence
/// `PreferredSizeWidget`, taller with the centre under the title.
final class StartAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StartAppBar({
    super.key,
    required this.sector,
    required this.showGallery,
  });

  /// The tournée open, or null.
  final SectorSummary? sector;

  /// Debug builds: an action opens the component gallery.
  final bool showGallery;

  @override
  Size get preferredSize => Size.fromHeight(
    sector == null ? kToolbarHeight : AppSizes.titleBarWithSubtitleHeight,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sector = this.sector;
    return AppBar(
      toolbarHeight: preferredSize.height,
      title: sector == null
          ? AppTitleButton(
              key: const Key('home.appTitle'),
              onPressed: () => showMySectorsSheet(context),
            )
          : SectorTitleButton(
              sector: sector,
              // `push`: Secteur stacks on Accueil, so its ← comes back here.
              onPressed: () => context.push(AppRoutes.team),
            ),
      titleSpacing: AppSizes.gutter,
      actions: [
        if (showGallery)
          IconButton(
            key: const Key('home.gallery'),
            tooltip: l10n.galleryTitle,
            icon: const Icon(Icons.widgets_outlined),
            // `push` stacks the gallery on top, so it offers a back arrow.
            onPressed: () => context.push(AppRoutes.gallery),
          ),
        IconButton(
          key: const Key('home.settings'),
          tooltip: l10n.screenSettings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.push(AppRoutes.settings),
        ),
      ],
    );
  }
}

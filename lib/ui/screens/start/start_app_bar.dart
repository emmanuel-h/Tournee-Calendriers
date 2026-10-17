import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/tournee/tournee_summary.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/my_tournees_sheet.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/tournee_title_button.dart';
import 'package:tournee_calendriers/ui/screens/team/team_button.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// The top bar of the start screen, Accueil's (PLAN §5.3, Home mockup) as
/// much as the phone's « Mes rues » (§5.0): the open tournée (« Tournée
/// 49 · 2026 ▾ » over its centre) opens « Mes tournées », 👥 opens Équipe
/// (with a dot while a request waits), ⚙ opens Paramètres. With no
/// tournée open, the app's name stays, opens « Mes tournées » too, and
/// there is no 👥.
///
/// A `Scaffold` asks its app bar for its height before building it: hence
/// `PreferredSizeWidget`, taller with the centre under the title.
final class StartAppBar extends StatelessWidget implements PreferredSizeWidget {
  const StartAppBar({
    super.key,
    required this.tournee,
    required this.showGallery,
  });

  /// The tournée open, or null.
  final TourneeSummary? tournee;

  /// Debug builds: an action opens the component gallery.
  final bool showGallery;

  @override
  Size get preferredSize => Size.fromHeight(
    tournee == null ? kToolbarHeight : AppSizes.titleBarWithSubtitleHeight,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tournee = this.tournee;
    return AppBar(
      toolbarHeight: preferredSize.height,
      title: tournee == null
          ? AppTitleButton(
              key: const Key('home.appTitle'),
              onPressed: () => showMyTourneesSheet(context),
            )
          : TourneeTitleButton(
              tournee: tournee,
              onPressed: () => showMyTourneesSheet(context),
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
        if (tournee != null) const TeamButton(key: Key('home.team')),
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

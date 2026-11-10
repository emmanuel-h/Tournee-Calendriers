import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/map/map_layers.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/size_reporter.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/map/map_view.dart';
import 'package:tournee_calendriers/ui/map/sector_map.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/my_sectors_sheet.dart';
import 'package:tournee_calendriers/ui/screens/start/start_app_bar.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// No secteur, no street: the map's background alone, on France until
/// « Me localiser » is tapped. Made once, so a rebuild sends the map
/// nothing new.
final _noStreets = MapLayers.of(const []);

/// Accueil with no secteur open (PLAN §5.0, NoSector mockup): the base map
/// with no street and no legend (« Me localiser » kept), and a panel
/// « Aucun secteur ouvert » with « Rejoindre un secteur » and, for an admin
/// only (§5.12), « Créer un secteur ». Streets only ever live in a
/// secteur: there is nothing to list here.
///
/// Its top bar is Accueil's ([StartAppBar]): the app's name opens « Mes
/// secteurs », ⚙ Paramètres.
///
/// A `ConsumerStatefulWidget`: the screen keeps the panel's measured
/// height in its `State`, so the map keeps « Me localiser »'s neighbours
/// (the attribution) clear of it.
final class NoSectorScreen extends ConsumerStatefulWidget {
  const NoSectorScreen({super.key, required this.showGallery});

  /// Debug builds: an app-bar action opens the component gallery.
  final bool showGallery;

  @override
  ConsumerState<NoSectorScreen> createState() => _NoSectorScreenState();
}

final class _NoSectorScreenState extends ConsumerState<NoSectorScreen> {
  /// How tall the panel is, so the map keeps clear of it.
  var _panelHeight = 0.0;

  @override
  Widget build(BuildContext context) {
    final showMap = ref.watch(sectorMapViewProvider);
    return Scaffold(
      appBar: StartAppBar(sector: null, showGallery: widget.showGallery),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned.fill(
                child: showMap(
                  SectorMap(
                    key: const Key('noSector.map'),
                    layers: _noStreets,
                    padding: EdgeInsets.only(bottom: _panelHeight),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ConstrainedBox(
                  // With very large text the panel scrolls rather than
                  // overflowing the screen.
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight),
                  child: SizeReporter(
                    onHeight: (height) {
                      if (mounted) setState(() => _panelHeight = height);
                    },
                    child: const _Panel(key: Key('noSector.panel')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The white sheet at the bottom: why nothing shows, and the way in.
final class _Panel extends ConsumerWidget {
  const _Panel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // Only an admin creates a secteur; nothing hints at it otherwise, as on
    // « Bienvenue ».
    final isAdmin = ref.watch(adminProvider);
    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.ink,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.sheetRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          10,
          AppSizes.gutter,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            // Decoration: the panel does not move, the handle only matches
            // Accueil's.
            Center(
              child: Container(
                width: AppSizes.dragHandleWidth,
                height: AppSizes.dragHandleHeight,
                decoration: BoxDecoration(
                  color: colors.line,
                  borderRadius: BorderRadius.circular(
                    AppSizes.dragHandleHeight / 2,
                  ),
                ),
              ),
            ),
            Semantics(
              header: true,
              child: Text(
                l10n.noSectorTitle,
                style: AppTextStyles.listHeader.copyWith(color: colors.ink),
              ),
            ),
            Text(
              l10n.noSectorBody,
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.muted,
                height: 1.4,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: PrimaryButton(
                key: const Key('noSector.join'),
                label: l10n.joinSectorAction,
                onPressed: () =>
                    unawaited(openWithName(context, AppRoutes.join)),
              ),
            ),
            if (isAdmin)
              SecondaryButton(
                key: const Key('noSector.create'),
                label: l10n.createSectorAction,
                onPressed: () =>
                    unawaited(openWithName(context, AppRoutes.create)),
              ),
          ],
        ),
      ),
    );
  }
}

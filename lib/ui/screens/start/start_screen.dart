import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_notifier.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/filter_field.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/start/street_row.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Mes rues », the temporary start screen of M1 (PLAN §5.0,
/// `docs/mockups/Start.dc.html`): the streets on the phone with their
/// progress, a filter, and « Importer des rues ». Works offline.
///
/// Temporary: Accueil (the map and its « Mes rues » panel, PLAN §5.3)
/// replaces it in M3.
///
/// A `ConsumerWidget` is a `StatelessWidget` that can read providers:
/// `ref.watch` redraws it whenever the list's state changes.
final class StartScreen extends ConsumerWidget {
  const StartScreen({super.key, required this.showGallery});

  /// Debug builds: an app-bar action opens the component gallery.
  final bool showGallery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(streetListProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
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
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: state.loading
                  ? const SizedBox.shrink()
                  : state.isEmpty
                  ? const _EmptyState()
                  : _StreetList(state: state),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.gutter,
                12,
                AppSizes.gutter,
                AppSizes.gutter,
              ),
              child: PrimaryButton(
                key: const Key('start.import'),
                icon: Icons.add,
                label: l10n.importStreetsAction,
                onPressed: () => context.push(AppRoutes.importStreets),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First launch: nothing imported yet.
final class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: [
            Text(
              l10n.startEmptyTitle,
              textAlign: TextAlign.center,
              style: AppTextStyles.listHeader.copyWith(color: colors.ink),
            ),
            Text(
              l10n.startEmptyBody,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Mes rues · 3 », the filter and the rows.
final class _StreetList extends ConsumerWidget {
  const _StreetList({required this.state});

  final StreetListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            14,
            AppSizes.gutter,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            spacing: 12,
            children: [
              Text(
                l10n.startStreetsHeader(state.streetCount),
                style: AppTextStyles.listHeader.copyWith(color: colors.ink),
              ),
              Expanded(
                child: Text(
                  state.communes.join(', '),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small.copyWith(color: colors.muted),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            0,
            AppSizes.gutter,
            6,
          ),
          child: FilterField(
            key: const Key('start.filter'),
            // `ref.read`, not `watch`: an intent is sent once, it does not
            // need the widget to redraw when the notifier changes.
            onChanged: ref.read(streetListProvider.notifier).filter,
          ),
        ),
        Expanded(
          child: state.rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSizes.gutter),
                  child: Text(
                    l10n.filterNoMatch(state.filter.trim()),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(color: colors.muted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.gutter,
                  ),
                  itemCount: state.rows.length,
                  itemBuilder: (context, index) {
                    final row = state.rows[index];
                    return StreetRowTile(
                      key: ValueKey('start.street.${row.id.value}'),
                      row: row,
                      // The street screen (#11) replaces the placeholder;
                      // the name travels along as its title meanwhile.
                      onTap: () => context.push(
                        AppRoutes.streetOf(row.id),
                        extra: row.name,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/presentation/collecte/which_house_notifier.dart';
import 'package:tournee_calendriers/ui/components/amber_note.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/start/street_row.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Quelle maison ? » (PLAN §5.20, mockup MarkForgotten), pushed by
/// « Marquer une maison » of Collecte: « Tournée du sam. 14 nov. · 1 maison
/// à marquer », the amber line, « Rechercher une rue » and the secteur's
/// streets with their progress. A street opens in « Touchez la maison
/// oubliée »; once a house is marked there, this screen goes back to
/// Collecte with what was marked (« N° 3 rue des Lilas marquée ✓. »).
/// Offline too: the streets are the phone's.
final class WhichHouseScreen extends ConsumerWidget {
  const WhichHouseScreen({super.key, required this.round});

  final RoundId round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final view = ref.watch(whichHouseProvider(round));
    final startedAt = view.startedAt;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(l10n.whichHouseTitle),
            if (startedAt != null)
              Text(
                l10n.whichHouseSubtitle(startedAt, view.housesToMark),
                key: const Key('whichHouse.subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.gutter,
                0,
                AppSizes.gutter,
                12,
              ),
              child: AmberNote(l10n.whichHouseInfo),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.gutter,
                0,
                AppSizes.gutter,
                12,
              ),
              child: TextField(
                key: const Key('whichHouse.search'),
                onChanged: ref.read(whichHouseProvider(round).notifier).filter,
                style: AppTextStyles.bodyLarge,
                textInputAction: TextInputAction.search,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: InputDecoration(
                  hintText: l10n.addStreetsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Divider(height: 1, color: colors.divider),
            Expanded(
              child: ListView(
                key: const Key('whichHouse.streets'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.gutter,
                ),
                children: [
                  for (final row in view.streets)
                    StreetRowTile(
                      key: ValueKey('whichHouse.street.${row.id.value}'),
                      row: row,
                      onTap: () async {
                        final marked = await context.push<String>(
                          AppRoutes.forgottenStreetOf(round, row.id),
                        );
                        if (marked != null && context.mounted) {
                          context.pop(marked);
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_notifier.dart';
import 'package:tournee_calendriers/presentation/my_sectors/my_sectors_state.dart';
import 'package:tournee_calendriers/presentation/my_sectors/offline_access.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/dashed_outline.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/settings/name_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// Opens « Mes secteurs » (« Changer de secteur » in Secteur, the app's
/// name with no secteur open, or Paramètres → Mes secteurs, PLAN §5.3,
/// Switcher mockup), then « Nouveau secteur », « Rejoindre un
/// secteur » or « Tous les secteurs » when the sheet's buttons chose one.
Future<void> showMySectorsSheet(BuildContext context) async {
  // The sheet closes with the screen to open, if any.
  final location = await showAppBottomSheet<String>(
    context: context,
    builder: (_) => const MySectorsSheet(),
  );
  if (location != null && context.mounted) {
    await openWithName(context, location);
  }
}

/// Opens [location] once the member has a first name, which the team will
/// see: « Votre prénom » first when the phone has none yet. From « Mes
/// secteurs » and from Accueil with no secteur open (PLAN §5.0).
Future<void> openWithName(BuildContext context, String location) async {
  if (!await ensureMemberName(context) || !context.mounted) return;
  // Not awaited: `push` ends only when the screen opened is closed.
  unawaited(context.push(location));
}

/// Whether the phone has a first name for the team to see, asking for it
/// (« Votre prénom ») when it has none yet: false when the sheet is closed
/// without one. Before creating, joining, or joining as an admin.
Future<bool> ensureMemberName(BuildContext context) async {
  // The providers of the app, read from outside a widget's `build`.
  final container = ProviderScope.containerOf(context, listen: false);
  if (container.read(settingsProvider).name != null) return true;
  await showNameSheet(context);
  return context.mounted && container.read(settingsProvider).name != null;
}

/// The member's secteurs: the open one (● and ✓), the others (a tap opens
/// one at once, and the app reopens it next time), and their requests not
/// accepted yet, which cannot be opened. Offline, a secteur never
/// downloaded on this phone is greyed and cannot be opened either
/// (« Disponible avec réseau »). Then « Créer un secteur » (an
/// admin only, PLAN §5.12) and « Rejoindre un secteur », and for an admin
/// « Tous les secteurs ›».
final class MySectorsSheet extends ConsumerWidget {
  const MySectorsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final rows = ref.watch(mySectorsProvider).rows;
    // Watched only here: whether the phone is offline is followed while
    // the sheet is shown, and the rows grey or come back with the network.
    final access = ref.watch(offlineAccessProvider);
    final isAdmin = ref.watch(adminProvider);
    return SheetScaffold(
      title: l10n.mySectorsTitle,
      spacing: 6,
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.mySectorsEmpty,
              key: const Key('mySectors.empty'),
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ),
        for (final row in rows)
          _SectorRowTile(
            key: ValueKey('mySectors.${row.id.value}'),
            row: row,
            unavailable: access.isUnavailable(row),
            onTap: switch (row.status) {
              SectorRowStatus.open => () => Navigator.of(context).pop(),
              SectorRowStatus.closed when access.isUnavailable(row) => null,
              SectorRowStatus.closed => () {
                unawaited(ref.read(mySectorsProvider.notifier).open(row.id));
                Navigator.of(context).pop();
              },
              SectorRowStatus.pending => null,
            },
          ),
        // The current secteur stays open until the new one is ready (or
        // accepted, PLAN §5.3).
        const SizedBox(height: 10),
        // Only admins create a secteur; nothing hints at it otherwise.
        if (isAdmin)
          PrimaryButton(
            key: const Key('mySectors.create'),
            label: l10n.createSectorAction,
            icon: Icons.add,
            compact: true,
            onPressed: () => Navigator.of(context).pop(AppRoutes.create),
          ),
        SecondaryButton(
          key: const Key('mySectors.join'),
          label: l10n.joinSectorAction,
          compact: true,
          onPressed: () => Navigator.of(context).pop(AppRoutes.join),
        ),
        if (isAdmin)
          TextButton.icon(
            key: const Key('mySectors.all'),
            onPressed: () => Navigator.of(context).pop(AppRoutes.allSectors),
            style: TextButton.styleFrom(
              foregroundColor: colors.ink,
              minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
              textStyle: AppTextStyles.compactButton,
            ),
            icon: const Icon(Icons.shield_outlined, size: AppSizes.smallIcon),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.mySectorsAll),
                const Icon(Icons.chevron_right, size: AppSizes.smallIcon),
              ],
            ),
          ),
      ],
    );
  }
}

/// One secteur: its mark, « Secteur 12 · 2026 » over its centre, and ✓
/// when it is the open one. Never told by colour alone: the open one has
/// ✓ and a filled mark, a request a dashed mark and its own words, and the
/// red dot of a request waiting in another secteur comes with « · 1
/// demande en attente ». A secteur greyed offline says « Disponible avec
/// réseau », and screen readers hear it disabled.
final class _SectorRowTile extends StatelessWidget {
  const _SectorRowTile({
    super.key,
    required this.row,
    required this.unavailable,
    required this.onTap,
  });

  final SectorRow row;

  /// Offline and not downloaded on this phone: greyed, cannot open.
  final bool unavailable;

  /// Null for a request, or a secteur [unavailable]: the row cannot be
  /// tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = l10n.sectorTitle('${row.number}', '${row.campaign}');
    final (subtitle, label) = switch (row.status) {
      // Before the requests waiting and the shield: none of it matters
      // while the secteur cannot open.
      SectorRowStatus.closed when unavailable => (
        l10n.mySectorsUnavailable(row.centre),
        l10n.mySectorsUnavailableSemantics(title, row.centre),
      ),
      SectorRowStatus.open when row.visited => (
        l10n.mySectorsVisited(row.centre),
        l10n.mySectorsVisitedOpenSemantics(title, row.centre),
      ),
      SectorRowStatus.open => (
        row.centre,
        l10n.mySectorsOpenSemantics(title, row.centre),
      ),
      SectorRowStatus.closed when row.waitingRequests > 0 => (
        l10n.mySectorsWaiting(row.centre, row.waitingRequests),
        l10n.mySectorsWaitingSemantics(title, row.centre, row.waitingRequests),
      ),
      SectorRowStatus.closed when row.visited => (
        l10n.mySectorsVisited(row.centre),
        l10n.mySectorsVisitedSemantics(title, row.centre),
      ),
      SectorRowStatus.closed => (
        row.centre,
        l10n.mySectorsClosedSemantics(title, row.centre),
      ),
      SectorRowStatus.pending => (
        l10n.mySectorsPending(row.centre),
        l10n.mySectorsPendingSemantics(title, row.centre),
      ),
    };
    final ink = unavailable
        ? colors.unavailable
        : row.status == SectorRowStatus.pending
        ? colors.muted
        : colors.ink;
    return Semantics(
      // A greyed secteur is still a button, a disabled one: TalkBack says
      // « désactivé », so the member knows a tap will not open it.
      button: onTap != null || unavailable,
      enabled: unavailable ? false : null,
      selected: row.status == SectorRowStatus.open,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.sectorRowHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Row(
            spacing: 14,
            children: [
              if (row.visited)
                // A shield instead of the ring: an admin who is not in the
                // team (PLAN §5.12). Said by the row's label.
                Icon(
                  Icons.shield_outlined,
                  key: Key('mySectors.${row.id.value}.shield'),
                  size: AppSizes.sectorMark,
                  color: row.status == SectorRowStatus.open
                      ? colors.doneInk
                      : unavailable
                      ? colors.unavailableMark
                      : colors.muted,
                )
              else
                _SectorMark(status: row.status, unavailable: unavailable),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.sectorRowTitle.copyWith(color: ink),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.small.copyWith(
                        color: unavailable ? colors.unavailable : colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (row.status == SectorRowStatus.open)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: StatusGlyph(
                    StatusGlyphs.done,
                    size: AppSizes.segmentGlyph,
                    color: colors.doneInk,
                  ),
                )
              // The open secteur's requests show on Accueil's title, not here.
              else if (row.status == SectorRowStatus.closed &&
                  !unavailable &&
                  row.waitingRequests > 0)
                Container(
                  key: Key('mySectors.${row.id.value}.dot'),
                  width: AppSizes.waitingDot,
                  height: AppSizes.waitingDot,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ● for the open secteur, ○ for another (paler when it cannot open
/// offline), a dashed ○ for a request.
final class _SectorMark extends StatelessWidget {
  const _SectorMark({required this.status, required this.unavailable});

  final SectorRowStatus status;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const side = AppSizes.sectorMark;
    return switch (status) {
      SectorRowStatus.open => Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.doneInk, width: 2),
        ),
        child: Container(
          width: AppSizes.sectorMarkDot,
          height: AppSizes.sectorMarkDot,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.doneInk,
          ),
        ),
      ),
      SectorRowStatus.closed => Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: unavailable ? colors.unavailableMark : colors.muted,
            width: 2,
          ),
        ),
      ),
      SectorRowStatus.pending => CustomPaint(
        size: const Size.square(side),
        painter: DashedOutlinePainter(colors.muted, radius: side / 2),
      ),
    };
  }
}

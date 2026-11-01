import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_state.dart';
import 'package:tournee_calendriers/presentation/my_tournees/offline_access.dart';
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

/// Opens « Mes tournées » (tap the title, or Paramètres → Mes tournées,
/// PLAN §5.3, Switcher mockup), then « Nouvelle tournée », « Rejoindre une
/// tournée » or « Toutes les tournées » when the sheet's buttons chose one.
Future<void> showMyTourneesSheet(BuildContext context) async {
  // The sheet closes with the screen to open, if any.
  final location = await showAppBottomSheet<String>(
    context: context,
    builder: (_) => const MyTourneesSheet(),
  );
  if (location != null && context.mounted) {
    await _openWithName(context, location);
  }
}

/// Opens [location] once the member has a first name, which the team will
/// see: « Votre prénom » first when the phone has none yet.
Future<void> _openWithName(BuildContext context, String location) async {
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

/// The member's tournées: the open one (● and ✓), the others (a tap opens
/// one at once, and the app reopens it next time), and their requests not
/// accepted yet, which cannot be opened. Offline, a tournée never
/// downloaded on this phone is greyed and cannot be opened either
/// (« Disponible avec réseau »). Then « Créer une tournée » (an
/// admin only, PLAN §5.12) and « Rejoindre une tournée », and for an admin
/// « Toutes les tournées ›».
final class MyTourneesSheet extends ConsumerWidget {
  const MyTourneesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final rows = ref.watch(myTourneesProvider).rows;
    // Watched only here: whether the phone is offline is followed while
    // the sheet is shown, and the rows grey or come back with the network.
    final access = ref.watch(offlineAccessProvider);
    final isAdmin = ref.watch(adminProvider);
    return SheetScaffold(
      title: l10n.myTourneesTitle,
      spacing: 6,
      children: [
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.myTourneesEmpty,
              key: const Key('myTournees.empty'),
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ),
        for (final row in rows)
          _TourneeRowTile(
            key: ValueKey('myTournees.${row.id.value}'),
            row: row,
            unavailable: access.isUnavailable(row),
            onTap: switch (row.status) {
              TourneeRowStatus.open => () => Navigator.of(context).pop(),
              TourneeRowStatus.closed when access.isUnavailable(row) => null,
              TourneeRowStatus.closed => () {
                unawaited(ref.read(myTourneesProvider.notifier).open(row.id));
                Navigator.of(context).pop();
              },
              TourneeRowStatus.pending => null,
            },
          ),
        // The current tournée stays open until the new one is ready (or
        // accepted, PLAN §5.3).
        const SizedBox(height: 10),
        // Only admins create a tournée; nothing hints at it otherwise.
        if (isAdmin)
          PrimaryButton(
            key: const Key('myTournees.create'),
            label: l10n.createTourneeAction,
            icon: Icons.add,
            compact: true,
            onPressed: () => Navigator.of(context).pop(AppRoutes.create),
          ),
        SecondaryButton(
          key: const Key('myTournees.join'),
          label: l10n.joinTourneeAction,
          compact: true,
          onPressed: () => Navigator.of(context).pop(AppRoutes.join),
        ),
        if (isAdmin)
          TextButton.icon(
            key: const Key('myTournees.all'),
            onPressed: () => Navigator.of(context).pop(AppRoutes.allTournees),
            style: TextButton.styleFrom(
              foregroundColor: colors.ink,
              minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
              textStyle: AppTextStyles.compactButton,
            ),
            icon: const Icon(Icons.shield_outlined, size: AppSizes.smallIcon),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.myTourneesAll),
                const Icon(Icons.chevron_right, size: AppSizes.smallIcon),
              ],
            ),
          ),
      ],
    );
  }
}

/// One tournée: its mark, « Tournée 12 · 2026 » over its centre, and ✓
/// when it is the open one. Never told by colour alone: the open one has
/// ✓ and a filled mark, a request a dashed mark and its own words, and the
/// red dot of a request waiting in another tournée comes with « · 1
/// demande en attente ». A tournée greyed offline says « Disponible avec
/// réseau », and screen readers hear it disabled.
final class _TourneeRowTile extends StatelessWidget {
  const _TourneeRowTile({
    super.key,
    required this.row,
    required this.unavailable,
    required this.onTap,
  });

  final TourneeRow row;

  /// Offline and not downloaded on this phone: greyed, cannot open.
  final bool unavailable;

  /// Null for a request, or a tournée [unavailable]: the row cannot be
  /// tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = l10n.tourneeTitle('${row.number}', '${row.campaign}');
    final (subtitle, label) = switch (row.status) {
      // Before the requests waiting and the shield: none of it matters
      // while the tournée cannot open.
      TourneeRowStatus.closed when unavailable => (
        l10n.myTourneesUnavailable(row.centre),
        l10n.myTourneesUnavailableSemantics(title, row.centre),
      ),
      TourneeRowStatus.open when row.visited => (
        l10n.myTourneesVisited(row.centre),
        l10n.myTourneesVisitedOpenSemantics(title, row.centre),
      ),
      TourneeRowStatus.open => (
        row.centre,
        l10n.myTourneesOpenSemantics(title, row.centre),
      ),
      TourneeRowStatus.closed when row.waitingRequests > 0 => (
        l10n.myTourneesWaiting(row.centre, row.waitingRequests),
        l10n.myTourneesWaitingSemantics(title, row.centre, row.waitingRequests),
      ),
      TourneeRowStatus.closed when row.visited => (
        l10n.myTourneesVisited(row.centre),
        l10n.myTourneesVisitedSemantics(title, row.centre),
      ),
      TourneeRowStatus.closed => (
        row.centre,
        l10n.myTourneesClosedSemantics(title, row.centre),
      ),
      TourneeRowStatus.pending => (
        l10n.myTourneesPending(row.centre),
        l10n.myTourneesPendingSemantics(title, row.centre),
      ),
    };
    final ink = unavailable
        ? colors.unavailable
        : row.status == TourneeRowStatus.pending
        ? colors.muted
        : colors.ink;
    return Semantics(
      // A greyed tournée is still a button, a disabled one: TalkBack says
      // « désactivé », so the member knows a tap will not open it.
      button: onTap != null || unavailable,
      enabled: unavailable ? false : null,
      selected: row.status == TourneeRowStatus.open,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.tourneeRowHeight,
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
                  key: Key('myTournees.${row.id.value}.shield'),
                  size: AppSizes.tourneeMark,
                  color: row.status == TourneeRowStatus.open
                      ? colors.done
                      : unavailable
                      ? colors.unavailableMark
                      : colors.muted,
                )
              else
                _TourneeMark(status: row.status, unavailable: unavailable),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.tourneeRowTitle.copyWith(color: ink),
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
              if (row.status == TourneeRowStatus.open)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: StatusGlyph(
                    StatusGlyphs.done,
                    size: AppSizes.segmentGlyph,
                    color: colors.done,
                  ),
                )
              // The open tournée's requests show on 👥, not here.
              else if (row.status == TourneeRowStatus.closed &&
                  !unavailable &&
                  row.waitingRequests > 0)
                Container(
                  key: Key('myTournees.${row.id.value}.dot'),
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

/// ● for the open tournée, ○ for another (paler when it cannot open
/// offline), a dashed ○ for a request.
final class _TourneeMark extends StatelessWidget {
  const _TourneeMark({required this.status, required this.unavailable});

  final TourneeRowStatus status;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    const side = AppSizes.tourneeMark;
    return switch (status) {
      TourneeRowStatus.open => Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.done, width: 2),
        ),
        child: Container(
          width: AppSizes.tourneeMarkDot,
          height: AppSizes.tourneeMarkDot,
          decoration: BoxDecoration(shape: BoxShape.circle, color: colors.done),
        ),
      ),
      TourneeRowStatus.closed => Container(
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
      TourneeRowStatus.pending => CustomPaint(
        size: const Size.square(side),
        painter: DashedOutlinePainter(colors.muted, radius: side / 2),
      ),
    };
  }
}

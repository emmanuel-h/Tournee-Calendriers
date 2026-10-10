import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/pending_sync/pending_sync_notifier.dart';
import 'package:tournee_calendriers/presentation/pending_sync/pending_sync_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « ☁ Modifications de 3 rues en attente d'envoi » (PLAN §5.3, §7, Home
/// mockup): shown only while changes made on this phone have not reached
/// the server, so that a member offline knows their marks are kept and
/// will leave with the network. Nothing at all otherwise.
final class PendingSyncLine extends ConsumerWidget {
  const PendingSyncLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(pendingSyncIndicatorProvider)) {
      AllSent() => const SizedBox.shrink(),
      ChangesWaiting(:final streets) => _Line(streets: streets),
    };
  }
}

final class _Line extends StatelessWidget {
  const _Line({required this.streets});

  final int streets;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context).pendingSyncLine(streets);
    final colors = AppColors.of(context);
    // One label for the line: the cloud says nothing a screen reader
    // should read on top of the text.
    return Semantics(
      key: const Key('start.pendingSync'),
      container: true,
      label: text,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.gutter,
          12,
          AppSizes.gutter,
          0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: AppSizes.pendingSyncGap,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: AppSizes.pendingSyncGlyph,
              color: colors.muted,
            ),
            // `Flexible`: a long text wraps instead of overflowing.
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

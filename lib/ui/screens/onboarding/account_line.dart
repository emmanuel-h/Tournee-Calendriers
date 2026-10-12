import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/account/account_notifier.dart';
import 'package:tournee_calendriers/presentation/account/account_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Where the phone's account stands, on « Nouvelle tournée » and
/// « Rejoindre » (PLAN §6.1, T2.1c): « Connexion au serveur… » while it
/// signs in, « Hors ligne » with « Réessayer » when it could not; nothing
/// once signed in, which is the usual case.
final class AccountLine extends ConsumerWidget {
  const AccountLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = AppTextStyles.small.copyWith(color: colors.muted);
    return switch (ref.watch(accountProvider)) {
      AccountSignedIn() => const SizedBox.shrink(),
      AccountSigningIn() => Semantics(
        liveRegion: true,
        child: Row(
          key: const Key('account.signingIn'),
          spacing: 10,
          children: [
            const SizedBox.square(
              dimension: AppSizes.pendingSyncGlyph,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            Expanded(child: Text(l10n.accountSigningIn, style: text)),
          ],
        ),
      ),
      AccountOffline() => Semantics(
        liveRegion: true,
        child: Row(
          key: const Key('account.offline'),
          spacing: 10,
          children: [
            // Decoration: the words say it.
            ExcludeSemantics(
              child: Icon(
                Icons.cloud_off_outlined,
                size: AppSizes.pendingSyncGlyph,
                color: colors.muted,
              ),
            ),
            Expanded(child: Text(l10n.accountOffline, style: text)),
            PillButton(
              key: const Key('account.retry'),
              label: l10n.retry,
              onPressed: () =>
                  unawaited(ref.read(accountProvider.notifier).retry()),
            ),
          ],
        ),
      ),
    };
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/round/round_notifier.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';

/// The top of Accueil's list, under the totals (PLAN §5.13, §5.14, mockup
/// RunStart): « ▶ Commencer une tournée », outlined in ink with the ▶ in
/// red, for a member of the secteur while no tournée is on. Nothing for an
/// admin visiting the secteur, nor while one is on: the « En tournée »
/// band on top shows it then (`RoundBand`).
final class RoundStartButton extends ConsumerWidget {
  const RoundStartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(roundProvider)) {
      RoundLoading() ||
      RoundOff(canStart: false) ||
      RoundOn() => const SizedBox.shrink(),
      RoundOff(canStart: true) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: SecondaryButton(
          key: const Key('round.start'),
          label: l10n.roundStart,
          strong: true,
          compact: true,
          leading: Icon(Icons.play_arrow, color: AppColors.of(context).accent),
          onPressed: () => unawaited(_start(context, ref)),
        ),
      ),
    };
  }

  /// Starts the tournée; the band takes the top bar's place. Refused only
  /// when one is on in another secteur (the button shows only to a member
  /// of the secteur): one at a time on a phone.
  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).roundAlreadyOnElsewhere;
    switch (await ref.read(roundProvider.notifier).start()) {
      case StartOutcome.alreadyOnElsewhere:
        showMessageSnackBar(messenger, message: message);
      case StartOutcome.started || StartOutcome.refused:
        break;
    }
  }
}

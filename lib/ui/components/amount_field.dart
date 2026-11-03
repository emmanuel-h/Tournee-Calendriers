import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/ui/components/keep_focus.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

// The parts of a don's form (PLAN §5.13): the status picker's « Montant du
// don » and « Autre montant », « Nouveau don » and « Modifier le don ».

/// « Espèces | Chèque | Carte », the chosen one in ink. Screen readers hear
/// a group « Moyen de paiement ». [name] names the parts for tests:
/// `<name>.method.cash`…
final class PaymentMethodChoice extends StatelessWidget {
  const PaymentMethodChoice({
    super.key,
    required this.name,
    required this.selected,
    required this.onSelected,
  });

  final String name;
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedChoice<PaymentMethod>(
      groupLabel: l10n.paymentMethodGroup,
      segments: [
        for (final method in PaymentMethod.values)
          Segment(
            value: method,
            label: methodChoiceName(l10n, method),
            key: ValueKey('$name.method.${method.name}'),
          ),
      ],
      selected: selected,
      onSelected: onSelected,
    );
  }
}

/// « Montant » over a large field with « € » at its end, the keyboard of
/// numbers open; under it [hint] (« Par exemple 7,50 »), or why what is
/// typed is refused ([error]). The field is `<name>.amount` in tests.
///
/// « OK » on the keyboard calls [onSubmitted] and keeps the keyboard open,
/// so a refused amount can be fixed at once (PLAN §5.13: « keyboard
/// kept »).
final class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.name,
    required this.controller,
    required this.error,
    required this.onSubmitted,
    this.hint,
  });

  final String name;
  final TextEditingController controller;
  final AmountFailure? error;
  final VoidCallback onSubmitted;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final error = this.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        // Screen readers hear « Montant » on the field itself (below):
        // a `MergeSemantics` around both trips a Flutter assertion with
        // the field's « € ».
        ExcludeSemantics(
          child: Text(
            l10n.amountLabel,
            style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
          ),
        ),
        Semantics(
          label: l10n.amountLabel,
          child: TextField(
            key: ValueKey('$name.amount'),
            controller: controller,
            autofocus: true,
            // Digits and a comma or a dot: `Amount.parse` takes both.
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onEditingComplete: keepFocusOnSubmit,
            onSubmitted: (_) => onSubmitted(),
            style: AppTextStyles.amountInput.copyWith(color: colors.ink),
            decoration: InputDecoration(
              constraints: const BoxConstraints(
                minHeight: AppSizes.amountFieldHeight,
              ),
              suffixText: l10n.amountSuffix,
              suffixStyle: AppTextStyles.amountInput.copyWith(
                color: colors.muted,
              ),
              helperText: hint,
              helperStyle: AppTextStyles.small.copyWith(color: colors.muted),
              errorText: error == null ? null : amountFailureText(l10n, error),
            ),
          ),
        ),
      ],
    );
  }
}

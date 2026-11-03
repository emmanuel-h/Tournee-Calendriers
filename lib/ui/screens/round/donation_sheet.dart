import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/presentation/round/round_view.dart';
import 'package:tournee_calendriers/ui/components/amount_field.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';

/// Opens « Modifier le don » over « Dons de la tournée » for the don of
/// [row] (PLAN §5.13, `docs/mockups/RunDon.dc.html`), on its method and
/// amount; without [row], « Nouveau don », empty, on Espèces. A free
/// calendar opens empty too: « Valider » makes it a don of money.
///
/// « Valider » gives [onSave] the don typed in and closes; « Annuler »
/// closes; « Supprimer ce don » (shown with [onRemove]) calls it and
/// closes. The future ends once the sheet is closed.
Future<void> showDonationSheet(
  BuildContext context, {
  DonationRow? row,
  required Future<void> Function(Donation donation) onSave,
  Future<void> Function()? onRemove,
}) {
  // Written here, where the translations are at hand: « 7,50 ».
  final (method, amount) = switch (row?.donation) {
    PaidDonation(:final method, :final amount) => (
      method,
      amountInputText(AppLocalizations.of(context), amount),
    ),
    FreeCalendar() || null => (PaymentMethod.cash, ''),
  };
  return showAppBottomSheet<void>(
    context: context,
    builder: (context) => _DonationSheet(
      editing: row != null,
      method: method,
      amount: amount,
      onSave: onSave,
      onRemove: onRemove,
    ),
  );
}

/// A `StatefulWidget`: the method chosen, the amount typed and why it was
/// refused belong to the sheet until « Valider ».
final class _DonationSheet extends StatefulWidget {
  const _DonationSheet({
    required this.editing,
    required this.method,
    required this.amount,
    required this.onSave,
    required this.onRemove,
  });

  /// « Modifier le don » rather than « Nouveau don ».
  final bool editing;

  /// The method and amount the form opens on.
  final PaymentMethod method;
  final String amount;

  final Future<void> Function(Donation donation) onSave;
  final Future<void> Function()? onRemove;

  @override
  State<_DonationSheet> createState() => _DonationSheetState();
}

final class _DonationSheetState extends State<_DonationSheet> {
  // `late`: set from the widget in their first use, after `widget` is
  // there.
  late var _method = widget.method;
  late final _amount = TextEditingController(text: widget.amount);
  AmountFailure? _error;

  /// « Valider » or « Supprimer » was tapped: a second tap does nothing.
  var _done = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onRemove = widget.onRemove;
    return SheetScaffold(
      title: widget.editing ? l10n.donationEditTitle : l10n.donationNewTitle,
      spacing: 16,
      children: [
        PaymentMethodChoice(
          name: 'donation',
          selected: _method,
          onSelected: (method) => setState(() => _method = method),
        ),
        AmountField(
          name: 'donation',
          controller: _amount,
          error: _error,
          onSubmitted: _save,
        ),
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: SecondaryButton(
                key: const Key('donation.cancel'),
                label: l10n.cancel,
                compact: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: PrimaryButton(
                key: const Key('donation.validate'),
                label: l10n.donationValidate,
                compact: true,
                onPressed: _save,
              ),
            ),
          ],
        ),
        if (onRemove != null)
          TextButton(
            key: const Key('donation.remove'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).accent,
              minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
            ),
            onPressed: () => _finish(onRemove),
            child: Text(l10n.donationRemove),
          ),
      ],
    );
  }

  /// « Valider »: the don typed, or why its amount is refused, under the
  /// field (the keyboard stays).
  void _save() {
    switch (Amount.parse(_amount.text)) {
      case Ok(value: final amount):
        _finish(() => widget.onSave(Donation.paid(_method, amount)));
      case Err(:final failure):
        setState(() => _error = failure);
    }
  }

  /// Runs [change] once and closes; the list behind shows the tournée as
  /// it then is.
  void _finish(Future<void> Function() change) {
    if (_done) return;
    _done = true;
    unawaited(change());
    Navigator.of(context).pop();
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/donation_totals.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/presentation/collecte/correct_round_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/correct_round_view.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/donation_tile.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/round/collecte_screen.dart';
import 'package:tournee_calendriers/ui/screens/round/donation_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Corriger la tournée » (PLAN §5.20, mockups RoundCorrectDons,
/// RoundCorrect, RoundCorrectConfirm), pushed by « ✎ Corriger » of
/// Collecte: « Don par don | Totaux » (only « Totaux » for a tournée that
/// kept no list), then « Enregistrer », which asks with the total before
/// and after, and pops `true` once saved (Collecte then says « Correction
/// enregistrée. »). Nothing changed, it just goes back. Saved on the phone
/// at once and sent when the network allows.
final class CorrectRoundScreen extends ConsumerStatefulWidget {
  const CorrectRoundScreen({super.key, required this.round});

  final RoundId round;

  @override
  ConsumerState<CorrectRoundScreen> createState() => _CorrectRoundState();
}

/// A `State` for the text fields of « Totaux »: each keeps what is typed
/// (and where the cursor is) while the notifier checks it.
final class _CorrectRoundState extends ConsumerState<CorrectRoundScreen> {
  final _counts = {
    for (final method in PaymentMethod.values) method: TextEditingController(),
  };
  final _amounts = {
    for (final method in PaymentMethod.values) method: TextEditingController(),
  };
  final _free = TextEditingController();

  /// The fields hold the tournée's figures: filled once, when first shown.
  var _filled = false;

  /// « Corriger » was tapped: a second tap does nothing.
  var _saving = false;

  CorrectRoundNotifier get _notifier =>
      ref.read(correctRoundProvider(widget.round).notifier);

  @override
  void dispose() {
    for (final controller in [..._counts.values, ..._amounts.values, _free]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The fields of « Totaux » from [view], the first time it shows.
  void _fill(CorrectRoundShown view) {
    if (_filled) return;
    _filled = true;
    final l10n = AppLocalizations.of(context);
    for (final method in PaymentMethod.values) {
      final draft = view.of(method);
      _counts[method]!.text = '${draft.count}';
      _amounts[method]!.text = sumInputText(l10n, draft.cents ?? 0);
    }
    _free.text = '${view.free}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final view = ref.watch(correctRoundProvider(widget.round));
    if (view is CorrectRoundShown) _fill(view);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Text(l10n.correctTitle),
            if (view is CorrectRoundShown)
              Text(
                l10n.correctSubtitle(
                  collecteWhen(l10n, view.startedAt, view.endedAt),
                  view.housesVisited,
                ),
                key: const Key('correct.subtitle'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.small.copyWith(color: colors.muted),
              ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: switch (view) {
          CorrectRoundGone() => const SizedBox.shrink(),
          final CorrectRoundShown view => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (view.hasList)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.gutter,
                    4,
                    AppSizes.gutter,
                    12,
                  ),
                  child: SegmentedChoice<CorrectionTab>(
                    key: const Key('correct.tabs'),
                    groupLabel: l10n.correctTabsLabel,
                    height: AppSizes.minTapTarget,
                    selected: view.tab,
                    onSelected: _notifier.selectTab,
                    segments: [
                      Segment(
                        value: CorrectionTab.donByDon,
                        label: l10n.correctTabDons,
                        key: const Key('correct.tab.dons'),
                      ),
                      Segment(
                        value: CorrectionTab.totals,
                        label: l10n.correctTabTotals,
                        key: const Key('correct.tab.totals'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: switch (view.tab) {
                  CorrectionTab.donByDon => _DonByDon(
                    view: view,
                    notifier: _notifier,
                  ),
                  CorrectionTab.totals => _Totals(
                    view: view,
                    notifier: _notifier,
                    counts: _counts,
                    amounts: _amounts,
                    free: _free,
                  ),
                },
              ),
              _Actions(
                view: view,
                onAdd: () => unawaited(
                  showDonationSheet(
                    context,
                    onSave: (donation) async => _notifier.addDonation(donation),
                  ),
                ),
                onSave: () => unawaited(_save(view)),
              ),
            ],
          ),
        },
      ),
    );
  }

  /// « Enregistrer »: back at once when nothing changed; otherwise « Corriger
  /// la tournée ? » with the total before and after, then saved.
  Future<void> _save(CorrectRoundShown view) async {
    final navigator = Navigator.of(context);
    if (!view.changed) {
      navigator.pop(false);
      return;
    }
    final l10n = AppLocalizations.of(context);
    String total(DonationTotals totals) =>
        l10n.correctConfirmTotal(totals.count, eurosText(l10n, totals.cents));
    final confirmed = await showConfirmDialog(
      context,
      name: 'correct.confirm',
      title: l10n.correctConfirmTitle,
      body: l10n.correctConfirmBody(total(view.before), total(view.after)),
      aside: l10n.correctConfirmAside,
      confirmLabel: l10n.correctConfirmOk,
      destructive: true,
    );
    if (!confirmed || _saving) return;
    _saving = true;
    final saved = await _notifier.save();
    if (mounted) navigator.pop(saved);
  }
}

/// « Don par don »: « 20 dons · 205 € · touchez un don pour le changer. »
/// and the dons newest first, each opening « Modifier le don ».
final class _DonByDon extends StatelessWidget {
  const _DonByDon({required this.view, required this.notifier});

  final CorrectRoundShown view;
  final CorrectRoundNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            l10n.correctDonsLine(roundTotalsText(l10n, view.after)),
            key: const Key('correct.donsLine'),
            style: AppTextStyles.small.copyWith(color: colors.muted),
          ),
        ),
        Divider(height: 1, color: colors.divider),
        Expanded(
          child: ListView(
            key: const Key('correct.dons'),
            children: [
              for (final (position, row) in view.donations.indexed)
                DonationTile(
                  key: ValueKey('correct.don.$position'),
                  donation: row.donation,
                  onTap: () => unawaited(
                    showDonationSheet(
                      context,
                      row: row,
                      onSave: (donation) async =>
                          notifier.changeDonation(row.index, donation),
                      onRemove: () async => notifier.removeDonation(row.index),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// « Totaux »: per method « Dons » and « Montant » side by side, why they
/// cannot stand under them, « Calendriers offerts », the live « Total »
/// and what does not change.
final class _Totals extends StatelessWidget {
  const _Totals({
    required this.view,
    required this.notifier,
    required this.counts,
    required this.amounts,
    required this.free,
  });

  final CorrectRoundShown view;
  final CorrectRoundNotifier notifier;
  final Map<PaymentMethod, TextEditingController> counts;
  final Map<PaymentMethod, TextEditingController> amounts;
  final TextEditingController free;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final freeFailure = view.freeFailure;
    return ListView(
      key: const Key('correct.totals'),
      children: [
        Divider(height: 1, color: colors.divider),
        for (final method in PaymentMethod.values)
          _MethodFields(
            method: method,
            draft: view.of(method),
            count: counts[method]!,
            amount: amounts[method]!,
            onCount: (count) => notifier.setCount(method, count),
            onAmount: (text) => notifier.setAmount(method, text),
          ),
        _Block(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Row(
                spacing: AppSizes.correctFieldGap,
                children: [
                  Expanded(
                    child: Text(
                      l10n.collecteFree,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: AppSizes.correctCountWidth,
                    child: _CountField(
                      fieldKey: const Key('correct.free'),
                      label: l10n.collecteFree,
                      controller: free,
                      faulty: freeFailure != null,
                      onChanged: notifier.setFree,
                    ),
                  ),
                ],
              ),
              if (freeFailure != null)
                _Refusal(totalFailureText(l10n, freeFailure, 0, 0)),
            ],
          ),
        ),
        Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.choiceRowHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: MergeSemantics(
            child: Row(
              spacing: 12,
              children: [
                Text(
                  l10n.recapTotal,
                  style: AppTextStyles.button.copyWith(color: colors.ink),
                ),
                // Wraps rather than overflows with a large total or font.
                Expanded(
                  child: Text(
                    roundTotalsText(l10n, view.after),
                    key: const Key('correct.total'),
                    textAlign: TextAlign.end,
                    style: AppTextStyles.roundTotals.copyWith(
                      color: colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Text(
            l10n.correctTotalsHelp,
            style: AppTextStyles.small.copyWith(color: colors.muted),
          ),
        ),
      ],
    );
  }
}

/// A white block of « Totaux » with a line under it.
final class _Block extends StatelessWidget {
  const _Block({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: child,
    );
  }
}

/// One method of « Totaux »: its name, « Dons » and « Montant » side by
/// side, and why they cannot stand under them.
final class _MethodFields extends StatelessWidget {
  const _MethodFields({
    required this.method,
    required this.draft,
    required this.count,
    required this.amount,
    required this.onCount,
    required this.onAmount,
  });

  final PaymentMethod method;
  final MethodDraft draft;
  final TextEditingController count;
  final TextEditingController amount;
  final ValueChanged<int> onCount;
  final ValueChanged<String> onAmount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final name = switch (method) {
      PaymentMethod.cash => l10n.paymentCash,
      PaymentMethod.cheque => l10n.paymentCheques,
      PaymentMethod.card => l10n.paymentCardLong,
    };
    final refusal = switch ((draft.amountFailure, draft.totalFailure)) {
      (final amount?, _) => amountFailureText(l10n, amount),
      (null, final total?) => totalFailureText(
        l10n,
        total,
        draft.count,
        draft.cents ?? 0,
      ),
      (null, null) => null,
    };
    final label = AppTextStyles.small.copyWith(color: colors.muted);
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Text(name, style: AppTextStyles.button.copyWith(color: colors.ink)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSizes.correctFieldGap,
            children: [
              SizedBox(
                width: AppSizes.correctCountWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    ExcludeSemantics(
                      child: Text(l10n.correctCount, style: label),
                    ),
                    _CountField(
                      fieldKey: ValueKey('correct.${method.name}.count'),
                      label: l10n.correctCountSpoken(name),
                      controller: count,
                      faulty: draft.totalFailure != null,
                      onChanged: onCount,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 4,
                  children: [
                    ExcludeSemantics(
                      child: Text(l10n.correctAmount, style: label),
                    ),
                    Semantics(
                      label: l10n.correctAmountSpoken(name),
                      child: TextField(
                        key: ValueKey('correct.${method.name}.amount'),
                        controller: amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp('[0-9 ,.]')),
                          LengthLimitingTextInputFormatter(12),
                        ],
                        onChanged: onAmount,
                        style: AppTextStyles.correctField.copyWith(
                          color: colors.ink,
                        ),
                        decoration: InputDecoration(
                          suffixText: l10n.amountSuffix,
                          suffixStyle: AppTextStyles.bodyLarge.copyWith(
                            color: colors.muted,
                          ),
                          enabledBorder: draft.amountFailure == null
                              ? null
                              : _faultyBorder(colors),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (refusal != null) _Refusal(refusal),
        ],
      ),
    );
  }
}

/// A field of a count (« Dons », « Calendriers offerts »): digits only, 4
/// at most (9 999, the bound of the rules), an empty field read as 0.
final class _CountField extends StatelessWidget {
  const _CountField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.faulty,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final bool faulty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: label,
      child: TextField(
        key: fieldKey,
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        onChanged: (text) => onChanged(text.isEmpty ? 0 : int.parse(text)),
        style: AppTextStyles.correctField.copyWith(color: colors.ink),
        decoration: InputDecoration(
          enabledBorder: faulty ? _faultyBorder(colors) : null,
        ),
      ),
    );
  }
}

/// The red edge of a field whose figure cannot stand (`.f.err`).
OutlineInputBorder _faultyBorder(AppColors colors) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
  borderSide: BorderSide(color: colors.accent, width: 2),
);

/// « ⚠ Au moins 1 don pour 20 €. » in red under a line.
final class _Refusal extends StatelessWidget {
  const _Refusal(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      '⚠ $text',
      style: AppTextStyles.small.copyWith(color: AppColors.of(context).accent),
    ),
  );
}

/// « Ajouter un don » (outlined, « Don par don » only) and « Enregistrer »
/// (red; greyed while a line cannot stand), pinned at the bottom.
final class _Actions extends StatelessWidget {
  const _Actions({
    required this.view,
    required this.onAdd,
    required this.onSave,
  });

  final CorrectRoundShown view;
  final VoidCallback onAdd;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          if (view.tab == CorrectionTab.donByDon)
            SecondaryButton(
              key: const Key('correct.add'),
              label: l10n.addDonation,
              strong: true,
              onPressed: onAdd,
            ),
          PrimaryButton(
            key: const Key('correct.save'),
            label: l10n.correctSave,
            onPressed: view.canSave ? onSave : null,
          ),
        ],
      ),
    );
  }
}

/// Why a total typed cannot stand, under its line: [count] dons and
/// [cents] the figures of the line.
String totalFailureText(
  AppLocalizations l10n,
  TotalFailure failure,
  int count,
  int cents,
) => switch (failure) {
  TotalFailure.amountMissing => l10n.correctAmountMissing(count),
  TotalFailure.countMissing => l10n.correctCountMissing(eurosText(l10n, cents)),
  TotalFailure.tooLarge => l10n.amountTooLarge,
  TotalFailure.tooMany => l10n.correctTooMany,
};

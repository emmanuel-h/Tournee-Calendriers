import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/amount.dart';
import 'package:tournee_calendriers/domain/round/donation.dart';
import 'package:tournee_calendriers/domain/round/payment_method.dart';
import 'package:tournee_calendriers/domain/shared/result.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/house_sheet/picker_step.dart';
import 'package:tournee_calendriers/presentation/round/given_donation.dart';
import 'package:tournee_calendriers/ui/components/amount_field.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/come_back_time_picker.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/last_change_text.dart';
import 'package:tournee_calendriers/ui/screens/street/status_words.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// Opens the status picker of one house over the street screen (a tap on
/// its tile, PLAN §5.6, `docs/mockups/House.dc.html`): « N° 7 » and, in
/// grey, its status. [onStored] hears each status the picker stores, for
/// the snackbar and its « Annuler »; during a tournée, a « Fait » is told
/// with its don. [onDonationAdded] hears a don given through « + Ajouter un
/// don ». The future ends once the picker is closed, whichever way.
Future<void> showHouseStatusPicker(
  BuildContext context,
  HouseSheetKey house, {
  required ValueChanged<StoredStatus> onStored,
  required ValueChanged<GivenDonation> onDonationAdded,
}) => showAppBottomSheet<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context);
    String number(HouseSheetShown state) =>
        l10n.statusPickerHouse(state.number.label);
    return StatusPickerSheet(
      provider: houseSheetProvider(house),
      name: 'house',
      goneMessage: l10n.houseGone,
      title: (state) => _NumberAndStatus(
        name: 'house',
        number: number(state),
        status: statusName(l10n, state.status!),
      ),
      comeBackSubject: number,
      takeBackLabel: l10n.donationCancelHouse,
      onStored: onStored,
      onDonationAdded: onDonationAdded,
    );
  },
);

/// The status picker of a house or a door (PLAN §5.6, mockups House,
/// HouseNobody, HouseComeBack, Building): one sheet, in steps
/// ([PickerStep]).
///
/// - **The statuses**: four 72 dp buttons in the status colours with their
///   glyph, two a row, the current one ringed (a radio group « Statut »);
///   « ✗ Personne » reads « ✗ De nouveau personne » on a house the team
///   comes back to. Then the tries (« ✗ 2 passages sans personne ») and the
///   last change. One tap stores the status ([onStored] hears it) and
///   closes, unless [stepAfter] names a step.
/// - **« Quand repasser ? »**, after « Repasser »: the day chips, the hour
///   and the summary line, each choice stored at once; « Valider » closes
///   once they all are.
/// - **« Montant du don »**, after a « Fait » stored while a tournée is on
///   (PLAN §5.13), or « + Ajouter un don » on a house done: « Espèces |
///   Chèque | Carte » (Espèces each time), 5 / 10 / 20 €, « Autre montant »
///   (its own step, the amount typed in) and « Calendrier offert ». A tap
///   gives the don to the tournée and closes. After « Fait », the « Fait »
///   is told to [onStored] only then, with its don: a « Fait » means a
///   calendar was handed over, so closing this step without a don puts the
///   house back as it was.
///
/// ✕, a swipe down, a tap on the dimmed screen or back close it with
/// nothing more stored.
///
/// A `ConsumerStatefulWidget`: what the house is comes from the notifier
/// (`ref.watch`), but which step shows is the sheet's own, like a page of
/// a small book.
final class StatusPickerSheet extends ConsumerStatefulWidget {
  const StatusPickerSheet({
    super.key,
    required this.provider,
    required this.name,
    required this.goneMessage,
    required this.title,
    required this.comeBackSubject,
    required this.takeBackLabel,
    required this.onStored,
    required this.onDonationAdded,
  });

  /// The notifier of the house or door (`houseSheetProvider(key)`…).
  final NotifierProvider<MarksSheetNotifier, HouseSheetState> provider;

  /// Names the parts for tests: `<name>.status.done`, `<name>.close`,
  /// `<name>.comeBackDay.2026-10-24`…
  final String name;

  /// Shown when the house or door is no longer on the phone.
  final String goneMessage;

  /// The title of the statuses (« N° 7  À faire »).
  final Widget Function(HouseSheetShown state) title;

  /// What « … · quand repasser ? » is about: « N° 5 », « Porte 51 ».
  final String Function(HouseSheetShown state) comeBackSubject;

  /// What the ✕ of « Montant du don » is said to do after « Fait »
  /// (« Annuler : la maison reprend son statut »).
  final String takeBackLabel;

  /// Told each status stored, as soon as it is; a « Fait » during a
  /// tournée once its don is given.
  final ValueChanged<StoredStatus> onStored;

  /// Told a don given through « + Ajouter un don ».
  final ValueChanged<GivenDonation> onDonationAdded;

  @override
  ConsumerState<StatusPickerSheet> createState() => _StatusPickerSheetState();
}

final class _StatusPickerSheetState extends ConsumerState<StatusPickerSheet> {
  var _step = PickerStep.statuses;

  /// A status is being stored: a second tap meanwhile is ignored, so a
  /// double tap stores one status, not two.
  var _picking = false;

  /// The « Fait » whose don « Montant du don » asks for; null when the step
  /// came from « + Ajouter un don », or shows not.
  StoredStatus? _awaitingDon;

  /// A don was chosen: the sheet closes, and the « Fait » stays.
  var _donGiven = false;

  /// The method of the don, Espèces each time the step opens.
  var _method = PaymentMethod.cash;

  /// What « Autre montant » holds, and why it was refused.
  final _amount = TextEditingController();
  AmountFailure? _amountError;

  MarksSheetNotifier get _notifier => ref.read(widget.provider.notifier);

  /// The quick amounts of « Montant du don »: 5, 10 and 20 €.
  static final _quickAmounts = [
    for (final euros in const [5, 10, 20])
      if (Amount.create(euros * 100) case Ok(:final value)) value,
  ];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // `ref.watch`: the sheet follows the house, changed here or by a
    // teammate; it also keeps the auto-disposed notifier alive while the
    // sheet shows.
    final state = ref.watch(widget.provider);
    // Told of every way the sheet closes (✕, a swipe, a tap beside it,
    // back), while it is still on screen: the place to put the house back
    // when « Montant du don » closes without a don.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _takeBackUnpaid();
      },
      child: SheetScaffold(
        spacing: 14,
        children: switch (state) {
          HouseSheetLoading() => const [],
          HouseSheetGone() => [
            Text(
              widget.goneMessage,
              key: ValueKey('${widget.name}.gone'),
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ],
          HouseSheetShown() => switch (_step) {
            PickerStep.statuses => _statuses(state),
            PickerStep.comeBackTime => _comeBackTime(state),
            PickerStep.donation => _donation(),
            PickerStep.otherAmount => _otherAmount(),
          },
        },
      ),
    );
  }

  /// The sheet closes: a « Fait » still waiting for its don goes back
  /// (PLAN §5.6), and nothing is told of it.
  void _takeBackUnpaid() {
    final awaiting = _awaitingDon;
    if (awaiting == null || _donGiven) return;
    unawaited(_notifier.takeBack(awaiting.change));
  }

  List<Widget> _statuses(HouseSheetShown state) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return [
      _TitleRow(name: widget.name, title: widget.title(state)),
      _StatusGrid(
        name: widget.name,
        current: state.status!,
        nobodyHomeAgain: state.offersNobodyHomeAgain,
        onPicked: (status) => unawaited(_pick(status)),
      ),
      // During a tournée, a house done takes another don (PLAN §5.6).
      if (state.offersDonation)
        SecondaryButton(
          key: ValueKey('${widget.name}.addDonation'),
          label: l10n.addDonation,
          leading: const Icon(Icons.add),
          strong: true,
          compact: true,
          onPressed: _addDonation,
        ),
      if (state.showsTries) _Tries(name: widget.name, tries: state.tries),
      if (state.lastChange case final change?)
        Text(
          lastChangeText(l10n, change),
          key: ValueKey('${widget.name}.lastChange'),
          textAlign: TextAlign.center,
          style: AppTextStyles.small.copyWith(color: colors.muted),
        ),
    ];
  }

  List<Widget> _comeBackTime(HouseSheetShown state) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return [
      _TitleRow(
        name: widget.name,
        title: Semantics(
          header: true,
          child: Text(
            l10n.statusPickerComeBack(widget.comeBackSubject(state)),
            key: ValueKey('${widget.name}.comeBackTitle'),
            style: AppTextStyles.title.copyWith(color: colors.ink),
          ),
        ),
      ),
      ComeBackTimePicker(
        name: widget.name,
        time: state.comeBackTime,
        // Greyed should a teammate change the status meanwhile.
        enabled: state.comeBack,
        titled: false,
        onDay: (day) => unawaited(_notifier.chooseComeBackDay(day)),
        onHour: (hour) => unawaited(_notifier.chooseComeBackHour(hour)),
      ),
      PrimaryButton(
        key: ValueKey('${widget.name}.validate'),
        label: l10n.statusPickerValidate,
        onPressed: () => unawaited(_validate()),
      ),
    ];
  }

  /// « Montant du don »: the method, the quick amounts, « Autre montant »
  /// and « Calendrier offert ».
  List<Widget> _donation() {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final name = widget.name;
    return [
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.donationStepTitle,
                key: ValueKey('$name.donationTitle'),
                style: AppTextStyles.title.copyWith(color: colors.ink),
              ),
            ),
          ),
          CloseIconButton(
            key: ValueKey('$name.close'),
            // After « Fait », the ✕ puts the house back: it says so.
            tooltip: _awaitingDon == null
                ? l10n.statusPickerClose
                : widget.takeBackLabel,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      PaymentMethodChoice(
        name: name,
        selected: _method,
        onSelected: (method) => setState(() => _method = method),
      ),
      Row(
        spacing: AppSizes.statusChoiceGap,
        children: [
          for (final amount in _quickAmounts)
            Expanded(
              child: SecondaryButton(
                key: ValueKey('$name.give.${amount.cents}'),
                label: eurosText(l10n, amount.cents),
                compact: true,
                onPressed: () =>
                    unawaited(_give(Donation.paid(_method, amount))),
              ),
            ),
        ],
      ),
      Row(
        spacing: AppSizes.statusChoiceGap,
        children: [
          Expanded(
            child: SecondaryButton(
              key: ValueKey('$name.otherAmount'),
              label: l10n.donationOtherAmount,
              compact: true,
              onPressed: () => setState(() {
                _amountError = null;
                _step = PickerStep.otherAmount;
              }),
            ),
          ),
          Expanded(
            child: SecondaryButton(
              key: ValueKey('$name.freeCalendar'),
              label: l10n.donationFreeCalendar,
              compact: true,
              onPressed: () => unawaited(_give(const Donation.free())),
            ),
          ),
        ],
      ),
    ];
  }

  /// « Autre montant »: the method chosen before, the amount typed in,
  /// « Valider ». The arrow goes back to « Montant du don ».
  List<Widget> _otherAmount() {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final name = widget.name;
    return [
      Row(
        spacing: 4,
        children: [
          IconButton(
            key: ValueKey('$name.otherAmountBack'),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _step = PickerStep.donation),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                l10n.donationOtherAmount,
                key: ValueKey('$name.otherAmountTitle'),
                style: AppTextStyles.title.copyWith(color: colors.ink),
              ),
            ),
          ),
        ],
      ),
      PaymentMethodChoice(
        name: name,
        selected: _method,
        onSelected: (method) => setState(() => _method = method),
      ),
      AmountField(
        name: name,
        controller: _amount,
        hint: l10n.amountHint,
        error: _amountError,
        onSubmitted: _giveTyped,
      ),
      PrimaryButton(
        key: ValueKey('$name.giveTyped'),
        label: l10n.donationValidate,
        onPressed: _giveTyped,
      ),
    ];
  }

  /// « + Ajouter un don »: « Montant du don » for a house already done; its
  /// ✕ only closes.
  void _addDonation() => setState(() {
    _awaitingDon = null;
    _method = PaymentMethod.cash;
    _step = PickerStep.donation;
  });

  /// « Valider » of « Autre montant »: the amount typed, or why it is
  /// refused, under the field (the keyboard stays).
  void _giveTyped() {
    switch (Amount.parse(_amount.text)) {
      case Ok(value: final amount):
        unawaited(_give(Donation.paid(_method, amount)));
      case Err(:final failure):
        setState(() => _amountError = failure);
    }
  }

  /// [donation] goes to the tournée; the sheet tells what was stored and
  /// closes. A second tap meanwhile gives nothing more.
  Future<void> _give(Donation donation) async {
    if (_donGiven) return;
    // Before the `await`: closed meanwhile, the sheet must not take the
    // « Fait » back from under its don.
    _donGiven = true;
    final given = await _notifier.giveDonation(donation);
    switch ((_awaitingDon, given)) {
      case (final awaiting?, final given?):
        widget.onStored(awaiting.withDonation(given));
      // No tournée any more (validated meanwhile): the « Fait » stays.
      case (final awaiting?, null):
        widget.onStored(awaiting);
      case (null, final given?):
        widget.onDonationAdded(given);
      case (null, null):
        break;
    }
    if (mounted) Navigator.of(context).pop();
  }

  /// A status tapped: stores it (the notifier knows when there is nothing
  /// to store), tells [StatusPickerSheet.onStored], then closes or moves to
  /// the next step. A « Fait » during a tournée is told once its don is
  /// given (« Montant du don »).
  Future<void> _pick(VisitStatus status) async {
    if (_picking) return;
    _picking = true;
    final roundOn = switch (ref.read(widget.provider)) {
      HouseSheetShown(:final roundOn) => roundOn,
      HouseSheetLoading() || HouseSheetGone() => false,
    };
    final StoredStatus? stored;
    try {
      stored = await _notifier.setStatus(status);
    } finally {
      _picking = false;
    }
    final step = stepAfter(status, roundOn: roundOn, stored: stored != null);
    if (step == PickerStep.donation && mounted) {
      setState(() {
        _awaitingDon = stored;
        _method = PaymentMethod.cash;
        _step = PickerStep.donation;
      });
      return;
    }
    // Told even when the sheet was closed meanwhile: it is stored.
    if (stored != null) widget.onStored(stored);
    if (!mounted) return;
    switch (step) {
      case final step?:
        setState(() => _step = step);
      case null:
        Navigator.of(context).pop();
    }
  }

  /// « Valider »: closes once the day and hour chosen are stored, so an
  /// « Annuler » tapped at once in the snackbar comes after them.
  Future<void> _validate() async {
    await _notifier.settled;
    if (mounted) Navigator.of(context).pop();
  }
}

/// The title of a step, with the ✕ at its end.
final class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.name, required this.title});

  final String name;
  final Widget title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: title),
      CloseIconButton(
        key: ValueKey('$name.close'),
        tooltip: AppLocalizations.of(context).statusPickerClose,
        onPressed: () => Navigator.of(context).pop(),
      ),
    ],
  );
}

/// « N° 7 » large and, in grey on the same line of writing, its status
/// (« À faire »). Screen readers hear one heading.
final class _NumberAndStatus extends StatelessWidget {
  const _NumberAndStatus({
    required this.name,
    required this.number,
    required this.status,
  });

  /// The number is found in tests as `<name>.number`.
  final String name;
  final String number;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MergeSemantics(
      child: Semantics(
        header: true,
        child: Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              number,
              key: ValueKey('$name.number'),
              style: AppTextStyles.sheetNumber.copyWith(color: colors.ink),
            ),
            Text(
              status,
              key: ValueKey('$name.current'),
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The status buttons, two a row; one alone on the last row takes the
/// whole width. Screen readers hear a group of radio buttons « Statut ».
final class _StatusGrid extends StatelessWidget {
  const _StatusGrid({
    required this.name,
    required this.current,
    required this.nobodyHomeAgain,
    required this.onPicked,
  });

  final String name;
  final VisitStatus current;

  /// « Personne » reads « De nouveau personne ».
  final bool nobodyHomeAgain;
  final ValueChanged<VisitStatus> onPicked;

  /// Where [status] sits: done first, as it is the most tapped, refused
  /// beside it (both end the visit); « À faire » last, alone on its row,
  /// as it undoes a visit.
  static int _place(VisitStatus status) => switch (status) {
    VisitStatus.done => 0,
    VisitStatus.refused => 1,
    VisitStatus.nobodyHome => 2,
    VisitStatus.comeBack => 3,
    VisitStatus.toDo => 4,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statuses = [...VisitStatus.values]
      ..sort((a, b) => _place(a).compareTo(_place(b)));
    Widget button(VisitStatus status) => _StatusButton(
      key: ValueKey('$name.status.${status.name}'),
      status: status,
      label: status == VisitStatus.nobodyHome && nobodyHomeAgain
          ? l10n.nobodyHomeAgain
          : statusName(l10n, status),
      current: status == current,
      onTap: () => onPicked(status),
    );
    return Semantics(
      label: l10n.houseStatusGroup,
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSizes.statusChoiceGap,
        children: [
          for (var i = 0; i < statuses.length; i += 2)
            // `IntrinsicHeight`: both buttons of a row as tall as the
            // taller, when « De nouveau personne » takes two lines.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSizes.statusChoiceGap,
                children: [
                  for (final status in statuses.skip(i).take(2))
                    Expanded(child: button(status)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One status: its glyph and word in its colours; [current] ringed in ink
/// a gap away, as on the tile behind.
final class _StatusButton extends StatelessWidget {
  const _StatusButton({
    super.key,
    required this.status,
    required this.label,
    required this.current,
    required this.onTap,
  });

  final VisitStatus status;
  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final look = StatusLook.of(tileStatusFor(status), colors);
    const radius = AppSizes.statusChoiceRadius;
    const ring = AppSizes.statusChoiceRing + AppSizes.statusChoiceRingGap;
    // `checked` in a mutually exclusive group: TalkBack says « case
    // d'option, cochée », like a radio button.
    return Semantics(
      label: label,
      button: true,
      checked: current,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Container(
        // The ring is always there, transparent but on the current one, so
        // every button keeps the same size.
        padding: const EdgeInsets.all(AppSizes.statusChoiceRingGap),
        decoration: BoxDecoration(
          border: Border.all(
            color: current ? colors.ink : Colors.transparent,
            width: AppSizes.statusChoiceRing,
          ),
          borderRadius: BorderRadius.circular(radius + ring),
        ),
        child: Material(
          color: look.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(color: look.border, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.statusChoiceHeight - 2 * ring,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    StatusGlyph(
                      look.glyph,
                      size: AppSizes.statusChoiceGlyph,
                      color: look.foreground,
                    ),
                    Flexible(
                      child: Text(
                        label,
                        style: AppTextStyles.statusChoice.copyWith(
                          color: look.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « ✗ 2 passages sans personne », on the pale yellow of the tries (#80).
final class _Tries extends StatelessWidget {
  const _Tries({required this.name, required this.tries});

  final String name;
  final int tries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.nobodyHomePale,
        borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
      ),
      child: Row(
        spacing: AppSizes.glyphGap * 2,
        children: [
          // Decoration: the words say it.
          ExcludeSemantics(
            child: StatusGlyph(
              StatusGlyphs.nobodyHome,
              size: AppSizes.segmentGlyph,
              color: colors.ink,
            ),
          ),
          Expanded(
            child: Text(
              l10n.nobodyHomeTries(tries),
              key: ValueKey('$name.tries'),
              style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

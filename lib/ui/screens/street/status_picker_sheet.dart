import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/presentation/house_sheet/picker_step.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/come_back_time_picker.dart';
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
/// grey, its status. [onStored] hears each status the picker stores, at
/// once, for the snackbar and its « Annuler »; the future ends once the
/// picker is closed, whichever way.
Future<void> showHouseStatusPicker(
  BuildContext context,
  HouseSheetKey house, {
  required ValueChanged<StoredStatus> onStored,
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
      onStored: onStored,
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
    required this.onStored,
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

  /// Told each status stored, as soon as it is.
  final ValueChanged<StoredStatus> onStored;

  @override
  ConsumerState<StatusPickerSheet> createState() => _StatusPickerSheetState();
}

final class _StatusPickerSheetState extends ConsumerState<StatusPickerSheet> {
  var _step = PickerStep.statuses;

  /// A status is being stored: a second tap meanwhile is ignored, so a
  /// double tap stores one status, not two.
  var _picking = false;

  MarksSheetNotifier get _notifier => ref.read(widget.provider.notifier);

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // `ref.watch`: the sheet follows the house, changed here or by a
    // teammate; it also keeps the auto-disposed notifier alive while the
    // sheet shows.
    final state = ref.watch(widget.provider);
    return SheetScaffold(
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
        },
      },
    );
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

  /// A status tapped: stores it (the notifier knows when there is nothing
  /// to store), tells [StatusPickerSheet.onStored], then closes or moves to
  /// the next step.
  Future<void> _pick(VisitStatus status) async {
    if (_picking) return;
    _picking = true;
    final StoredStatus? stored;
    try {
      stored = await _notifier.setStatus(status);
    } finally {
      _picking = false;
    }
    // Told even when the sheet was closed meanwhile: it is stored.
    if (stored != null) widget.onStored(stored);
    if (!mounted) return;
    switch (stepAfter(status)) {
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

  /// Where [status] sits: done first, as it is the most tapped; « À faire »
  /// last, as it undoes a visit.
  static int _place(VisitStatus status) => switch (status) {
    VisitStatus.done => 0,
    VisitStatus.nobodyHome => 1,
    VisitStatus.comeBack => 2,
    VisitStatus.toDo => 3,
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

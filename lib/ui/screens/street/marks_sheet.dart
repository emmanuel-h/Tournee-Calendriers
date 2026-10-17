import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/come_back_block.dart';
import 'package:tournee_calendriers/ui/components/come_back_time_picker.dart';
import 'package:tournee_calendriers/ui/components/nobody_home_block.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/last_change_text.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// The sheet of marks of a house, a door or a building itself (PLAN §5.7,
/// `docs/mockups/House.dc.html`, `HouseComeBack.dc.html`): a title, the
/// status control « À faire | Fait | Personne | Repasser », the tries with
/// nobody home and « Repassé, toujours personne » (`HouseNobody.dc.html`,
/// enabled while it is « Personne » or « Repasser »), « Quand repasser ? »
/// (a building itself has the « Repasser » box instead of both), an
/// optional [action], « Annuler » and « OK » on a sheet a tap opened
/// ([onCancelTap]), and the last change. Every control is stored as soon as
/// it changes; the tile behind follows at once.
///
/// Choosing a status moves nothing on the sheet: the block of the tries and
/// « Quand repasser ? » are always there, greyed unless their statuses are
/// chosen, and the line of the last change keeps its place before the
/// first change.
///
/// A `ConsumerWidget`: the sheet keeps nothing of its own, every choice
/// goes to the notifier at once.
final class MarksSheet extends ConsumerWidget {
  const MarksSheet({
    super.key,
    required this.provider,
    required this.name,
    required this.goneMessage,
    required this.title,
    this.action,
    this.onNobodyHomeAgain,
    this.onCancelTap,
  });

  /// The notifier of what the sheet shows (`houseSheetProvider(key)`…).
  final NotifierProvider<MarksSheetNotifier, HouseSheetState> provider;

  /// Names the parts for tests: `<name>.status.done`,
  /// `<name>.comeBackDay.2026-10-24`…
  final String name;

  /// Shown when what the sheet shows is no longer on the phone.
  final String goneMessage;

  /// The title of the sheet (« 5 Rue des Lilas »).
  final Widget Function(HouseSheetShown state) title;

  /// A button under « Quand repasser ? » (« Transformer en immeuble… »).
  final Widget? action;

  /// « Repassé, toujours personne »: called once every change asked before
  /// is stored, to close the sheet so the screen behind marks the house or
  /// door and offers « Annuler ». Null on a building's own sheet, which has
  /// no status.
  final VoidCallback? onNobodyHomeAgain;

  /// Given on a sheet a tap to « Repasser » opened (#81): the sheet then
  /// ends with « Annuler » and « OK ». « Annuler » waits for every change
  /// asked to be stored, then calls this to close the sheet so the screen
  /// behind undoes the tap; « OK » just closes.
  final VoidCallback? onCancelTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // `ref.watch`: the sheet redraws at each change of the house, made here
    // or by a teammate; it also keeps the auto-disposed notifier alive
    // while the sheet shows.
    final state = ref.watch(provider);
    // `ref.read`, in the callbacks only: reading the notifier asks for no
    // redraw.
    MarksSheetNotifier notifier() => ref.read(provider.notifier);
    return SheetScaffold(
      children: switch (state) {
        HouseSheetLoading() => const [],
        HouseSheetGone() => [
          Text(
            goneMessage,
            key: ValueKey('$name.gone'),
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
        HouseSheetShown(:final status) => [
          title(state),
          ...switch (status) {
            // A building itself: no status, its own « Repasser » box.
            null => [
              ComeBackBlock(
                name: name,
                ticked: state.comeBack,
                onChanged: (on) => unawaited(notifier().setComeBack(on: on)),
                time: _timePicker(state, notifier),
              ),
            ],
            final VisitStatus status => [
              _StatusControl(
                name: name,
                status: status,
                onSelected: (status) => unawaited(notifier().setStatus(status)),
              ),
              if (onNobodyHomeAgain case final leave?)
                NobodyHomeBlock(
                  name: name,
                  tries: state.tries,
                  onNobodyHomeAgain: state.offersNobodyHomeAgain
                      ? () => unawaited(_afterChanges(notifier(), leave))
                      : null,
                ),
              _ComeBackTimeBlock(
                name: name,
                on: state.comeBack,
                picker: _timePicker(state, notifier),
              ),
            ],
          },
          ?action,
          if (onCancelTap case final cancel?)
            _TapButtons(
              name: name,
              onCancel: () => unawaited(_afterChanges(notifier(), cancel)),
              onOk: () => Navigator.of(context).pop(),
            ),
          // An empty line until the first change, so that change does not
          // move the sheet either.
          switch (state.lastChange) {
            null => const Text('', style: AppTextStyles.small),
            final change => Text(
              lastChangeText(l10n, change),
              key: ValueKey('$name.lastChange'),
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: colors.muted),
            ),
          },
        ],
      },
    );
  }

  /// « Quand repasser ? » of [state], each choice stored at once.
  Widget _timePicker(
    HouseSheetShown state,
    MarksSheetNotifier Function() notifier,
  ) => ComeBackTimePicker(
    name: name,
    time: state.comeBackTime,
    enabled: state.comeBack,
    onDay: (day) => unawaited(notifier().chooseComeBackDay(day)),
    onHour: (hour) => unawaited(notifier().chooseComeBackHour(hour)),
  );

  /// Calls [leave] once every change asked so far is stored, so what the
  /// screen behind does next (mark the house « personne » again, undo the
  /// tap) starts from them rather than racing them.
  static Future<void> _afterChanges(
    MarksSheetNotifier notifier,
    VoidCallback leave,
  ) async {
    await notifier.settled;
    leave();
  }
}

/// « Annuler » and « OK » side by side, on a sheet a tap opened
/// (mockup HouseComeBack): « Annuler » outlined, « OK » in the accent red.
final class _TapButtons extends StatelessWidget {
  const _TapButtons({
    required this.name,
    required this.onCancel,
    required this.onOk,
  });

  final String name;
  final VoidCallback onCancel;
  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      spacing: 12,
      children: [
        Expanded(
          child: SecondaryButton(
            key: ValueKey('$name.cancelTap'),
            label: l10n.comeBackSheetCancel,
            compact: true,
            onPressed: onCancel,
          ),
        ),
        Expanded(
          child: PrimaryButton(
            key: ValueKey('$name.ok'),
            label: l10n.comeBackSheetOk,
            compact: true,
            onPressed: onOk,
          ),
        ),
      ],
    );
  }
}

/// « Quand repasser ? » under the status control of a house or a door: in
/// the blue of « Repasser » when that status is chosen ([on]), greyed
/// otherwise, always the same size.
final class _ComeBackTimeBlock extends StatelessWidget {
  const _ComeBackTimeBlock({
    required this.name,
    required this.on,
    required this.picker,
  });

  /// Names the block for tests: `<name>.comeBackBlock`.
  final String name;
  final bool on;
  final Widget picker;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      key: ValueKey('$name.comeBackBlock'),
      padding: const EdgeInsets.all(AppSizes.comeBackPadding),
      decoration: BoxDecoration(
        color: on ? colors.comeBack : colors.ground,
        borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
      ),
      child: picker,
    );
  }
}

/// The title of a sheet: [big] (the number « 5 », the door « 51 ») large,
/// [beside] it on the same line of writing (« Rue des Lilas »). Screen
/// readers hear one heading.
final class MarksSheetTitle extends StatelessWidget {
  const MarksSheetTitle({
    super.key,
    required this.name,
    required this.big,
    required this.beside,
  });

  /// The big text is found in tests as `<name>.number`.
  final String name;
  final String big;
  final String beside;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return MergeSemantics(
      child: Semantics(
        header: true,
        child: Row(
          // Both texts sit on one line of writing, as in the mockup.
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          spacing: 10,
          children: [
            Text(
              big,
              key: ValueKey('$name.number'),
              style: AppTextStyles.sheetNumber.copyWith(color: colors.ink),
            ),
            Expanded(
              child: Text(
                beside,
                style: AppTextStyles.sheetStreetName.copyWith(
                  color: colors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « ○ À faire | ✓ Fait | ✗ Personne | ↻ Repasser », each glyph above its
/// word: screen readers hear a group of radio buttons named « Statut ».
final class _StatusControl extends StatelessWidget {
  const _StatusControl({
    required this.name,
    required this.status,
    required this.onSelected,
  });

  final String name;
  final VisitStatus status;
  final ValueChanged<VisitStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SegmentedChoice<VisitStatus>(
      groupLabel: l10n.houseStatusGroup,
      selected: status,
      onSelected: onSelected,
      height: AppSizes.statusSegmentHeight,
      textStyle: AppTextStyles.segment,
      glyphAbove: true,
      segments: [
        for (final option in VisitStatus.values)
          Segment(
            value: option,
            key: ValueKey('$name.status.${option.name}'),
            glyph: switch (option) {
              VisitStatus.toDo => StatusGlyphs.toDo,
              VisitStatus.done => StatusGlyphs.done,
              VisitStatus.nobodyHome => StatusGlyphs.nobodyHome,
              VisitStatus.comeBack => StatusGlyphs.comeBack,
            },
            label: switch (option) {
              VisitStatus.toDo => l10n.statusToDo,
              VisitStatus.done => l10n.statusDone,
              VisitStatus.nobodyHome => l10n.statusNobodyHome,
              VisitStatus.comeBack => l10n.statusComeBack,
            },
          ),
      ],
    );
  }
}

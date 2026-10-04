import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/components/status_glyph.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/last_change_text.dart';
import 'package:tournee_calendriers/ui/screens/street/limited_text_field.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// Opens the Fiche maison of one house over the street screen (hold a
/// tile, PLAN §5.7, `docs/mockups/House.dc.html`).
Future<void> showHouseSheet(BuildContext context, HouseSheetKey house) =>
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => HouseSheet(house: house),
    );

/// The Fiche maison: number and street, the status control, « Repasser »
/// with its hint, the note, and the last change. Every control is stored
/// as soon as it changes; the tile behind follows at once.
///
/// The two text fields are stored when they could otherwise be lost: when
/// the field loses focus (« OK » on the keyboard, another field), before
/// another control of the sheet is used, when the sheet closes (however it
/// is closed), and when the app goes to the background (Android may then
/// end it without warning). Not at each key: that would stamp the house and
/// rewrite the street at every letter.
final class HouseSheet extends ConsumerStatefulWidget {
  const HouseSheet({super.key, required this.house});

  final HouseSheetKey house;

  @override
  ConsumerState<HouseSheet> createState() => _HouseSheetState();
}

final class _HouseSheetState extends ConsumerState<HouseSheet> {
  final _hint = TextEditingController();
  final _note = TextEditingController();
  final _hintFocus = FocusNode();
  final _noteFocus = FocusNode();

  /// Kept to store the fields in [dispose], where `ref` is no longer
  /// usable. The notifier still lives then: the sheet's subscription to it
  /// ends just after.
  late final HouseSheetNotifier _notifier;

  /// Tells when the app goes to the background.
  late final AppLifecycleListener _lifecycle;

  /// The fields got the stored texts once; after that they hold what is
  /// typed, whatever the street says.
  var _filled = false;

  @override
  void initState() {
    super.initState();
    final provider = houseSheetProvider(widget.house);
    // `listenManual` (not `ref.listen` in `build`): runs once now with the
    // current state (`fireImmediately`), then at each change, outside any
    // build, so it may set the fields' texts. Listening first keeps the
    // auto-disposed notifier alive for the `read` below.
    ref.listenManual(provider, _follow, fireImmediately: true);
    _notifier = ref.read(provider.notifier);
    _hintFocus.addListener(() {
      if (!_hintFocus.hasFocus) _saveHint();
    });
    _noteFocus.addListener(() {
      if (!_noteFocus.hasFocus) _saveNote();
    });
    _lifecycle = AppLifecycleListener(onHide: _saveTexts);
  }

  void _follow(HouseSheetState? previous, HouseSheetState next) {
    if (next is! HouseSheetShown) return;
    if (!_filled) {
      _filled = true;
      _hint.text = next.comeBackHint;
      _note.text = next.note;
    } else if (previous is HouseSheetShown &&
        previous.comeBack &&
        !next.comeBack) {
      // « Repasser » was unticked, or « Fait » chosen: its hint is gone.
      _hint.clear();
    }
  }

  @override
  void dispose() {
    _saveTexts();
    _lifecycle.dispose();
    _hint.dispose();
    _note.dispose();
    _hintFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _saveHint() => unawaited(_notifier.saveComeBackHint(_hint.text));

  void _saveNote() => unawaited(_notifier.saveNote(_note.text));

  void _saveTexts() {
    _saveHint();
    _saveNote();
  }

  /// Another control is used: the texts are stored first, so the change
  /// that follows starts from them (the notifier runs changes in order).
  void _setStatus(VisitStatus status) {
    _saveTexts();
    unawaited(_notifier.setStatus(status));
  }

  void _setComeBack(bool on) {
    _saveTexts();
    unawaited(_notifier.setComeBack(on: on));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(houseSheetProvider(widget.house));
    return SheetScaffold(
      children: switch (state) {
        HouseSheetLoading() => const [],
        HouseSheetGone() => [
          Text(
            l10n.houseGone,
            key: const Key('house.gone'),
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
        HouseSheetShown() => [
          _Title(state: state),
          _StatusControl(status: state.status, onSelected: _setStatus),
          _ComeBackBlock(
            state: state,
            onChanged: _setComeBack,
            hint: LimitedTextField(
              name: 'house.comeBackHint',
              controller: _hint,
              focusNode: _hintFocus,
              limit: TextLimit.comeBackHint,
              tooLongMessage: l10n.comeBackHintTooLong(
                TextLimit.comeBackHint.max,
              ),
              placeholder: l10n.comeBackHintPlaceholder,
              borderColor: colors.comeBackBorder,
            ),
          ),
          LimitedTextField(
            name: 'house.note',
            controller: _note,
            focusNode: _noteFocus,
            limit: TextLimit.note,
            tooLongMessage: l10n.noteTooLong(TextLimit.note.max),
            label: l10n.noteLabel,
            maxLines: 4,
            helper: l10n.notePrivacyHint,
          ),
          if (state.lastChange case final change?)
            Text(
              lastChangeText(l10n, change),
              key: const Key('house.lastChange'),
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: colors.muted),
            ),
        ],
      },
    );
  }
}

/// « 5 Rue des Lilas »: the number large, the street beside it.
final class _Title extends StatelessWidget {
  const _Title({required this.state});

  final HouseSheetShown state;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // One heading for screen readers: « 5 Rue des Lilas ».
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
              state.number.label,
              key: const Key('house.number'),
              style: AppTextStyles.sheetNumber.copyWith(color: colors.ink),
            ),
            Expanded(
              child: Text(
                state.streetName,
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

/// « ○ À faire | ✓ Fait | ✗ Personne »: one choice, the chosen one in ink.
/// Screen readers hear a group of radio buttons named « Statut ».
final class _StatusControl extends StatelessWidget {
  const _StatusControl({required this.status, required this.onSelected});

  final VisitStatus status;
  final ValueChanged<VisitStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final divider = BorderSide(color: colors.line, width: AppSizes.borderWidth);
    return Semantics(
      label: l10n.houseStatusGroup,
      container: true,
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          border: Border.fromBorderSide(divider),
          borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
        ),
        // Clips the chosen segment's ink to the rounded corners.
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final (index, option) in VisitStatus.values.indexed)
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: index == 0 ? BorderSide.none : divider,
                    ),
                  ),
                  child: _Segment(
                    status: option,
                    selected: option == status,
                    onTap: () => onSelected(option),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

final class _Segment extends StatelessWidget {
  const _Segment({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final VisitStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final foreground = selected ? colors.surface : colors.ink;
    final (glyph, label) = switch (status) {
      VisitStatus.toDo => (StatusGlyphs.toDo, l10n.statusToDo),
      VisitStatus.done => (StatusGlyphs.done, l10n.statusDone),
      VisitStatus.nobodyHome => (
        StatusGlyphs.nobodyHome,
        l10n.statusNobodyHome,
      ),
    };
    // `checked` in a mutually exclusive group: TalkBack says « case
    // d'option, cochée », like a radio button.
    return Semantics(
      key: ValueKey('house.status.${status.name}'),
      label: label,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      onTap: selected ? null : onTap,
      child: Material(
        color: selected ? colors.ink : colors.surface,
        child: InkWell(
          // Choosing the status the house has changes nothing.
          onTap: selected ? null : onTap,
          child: SizedBox(
            height: AppSizes.segmentHeight,
            // A large text setting shrinks the label rather than cutting it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  spacing: 6,
                  children: [
                    StatusGlyph(
                      glyph,
                      size: AppSizes.segmentGlyph,
                      color: foreground,
                    ),
                    Text(
                      label,
                      style: AppTextStyles.compactButton.copyWith(
                        color: foreground,
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

/// The blue block: « ☑ ↻ Repasser » and, once ticked, when to come back.
/// On a done house the box is disabled and says why.
final class _ComeBackBlock extends StatelessWidget {
  const _ComeBackBlock({
    required this.state,
    required this.onChanged,
    required this.hint,
  });

  final HouseSheetShown state;
  final ValueChanged<bool> onChanged;

  /// The hint field, shown while « Repasser » is ticked.
  final Widget hint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final enabled = state.canComeBack;
    final foreground = enabled ? colors.onComeBack : colors.muted;
    void toggle() => onChanged(!state.comeBack);
    return Container(
      padding: const EdgeInsets.all(AppSizes.comeBackPadding),
      decoration: BoxDecoration(
        color: enabled ? colors.comeBack : colors.ground,
        borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          // One node for screen readers: « Repasser, case à cocher, non
          // cochée, désactivée, Déjà fait : rien à repasser. »
          MergeSemantics(
            child: InkWell(
              key: const Key('house.comeBack'),
              onTap: enabled ? toggle : null,
              borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The whole row answers taps over at least 48 dp, so the
                  // box itself can keep the mockup's size.
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AppSizes.minTapTarget,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: state.comeBack,
                          onChanged: enabled ? (_) => toggle() : null,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          fillColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? foreground
                                : Colors.transparent,
                          ),
                          checkColor: colors.surface,
                          side: BorderSide(color: foreground, width: 2),
                        ),
                        const SizedBox(width: 8),
                        StatusGlyph(
                          StatusGlyphs.comeBack,
                          size: AppSizes.comeBackGlyph,
                          color: foreground,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.comeBack,
                          style: AppTextStyles.button.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!enabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: Text(
                        l10n.comeBackDoneReason,
                        key: const Key('house.comeBackDisabled'),
                        style: AppTextStyles.small.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (state.comeBack) hint,
        ],
      ),
    );
  }
}

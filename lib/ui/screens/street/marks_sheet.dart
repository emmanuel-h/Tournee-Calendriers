import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/visit_status.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_notifier.dart';
import 'package:tournee_calendriers/presentation/house_sheet/house_sheet_state.dart';
import 'package:tournee_calendriers/ui/components/come_back_block.dart';
import 'package:tournee_calendriers/ui/components/limited_text_field.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/street/last_change_text.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:tournee_calendriers/ui/theme/status_look.dart';

/// The sheet of marks of a house, a door or a building itself (PLAN §5.7,
/// `docs/mockups/House.dc.html`): a title, the status control (not on a
/// building itself), « Repasser » with its hint, the note, an optional
/// [action], and the last change. Every control is stored as soon as it
/// changes; the tile behind follows at once.
///
/// The two text fields are stored when they could otherwise be lost: when
/// the field loses focus (« OK » on the keyboard, another field), before
/// another control of the sheet is used, when the sheet closes (however it
/// is closed), and when the app goes to the background (Android may then
/// end it without warning). Not at each key: that would stamp the house and
/// rewrite the street at every letter.
final class MarksSheet extends ConsumerStatefulWidget {
  const MarksSheet({
    super.key,
    required this.provider,
    required this.name,
    required this.goneMessage,
    required this.title,
    this.action,
  });

  /// The notifier of what the sheet shows (`houseSheetProvider(key)`…).
  final NotifierProvider<MarksSheetNotifier, HouseSheetState> provider;

  /// Names the parts for tests: `<name>.status.done`, `<name>.note.field`…
  final String name;

  /// Shown when what the sheet shows is no longer on the phone.
  final String goneMessage;

  /// The title of the sheet (« 5 Rue des Lilas »).
  final Widget Function(HouseSheetShown state) title;

  /// A button under the note (« Transformer en immeuble… »).
  final Widget? action;

  @override
  ConsumerState<MarksSheet> createState() => _MarksSheetState();
}

final class _MarksSheetState extends ConsumerState<MarksSheet> {
  final _hint = TextEditingController();
  final _note = TextEditingController();
  final _hintFocus = FocusNode();
  final _noteFocus = FocusNode();

  /// Kept to store the fields in [dispose], where `ref` is no longer
  /// usable. The notifier still lives then: the sheet's subscription to it
  /// ends just after.
  late final MarksSheetNotifier _notifier;

  /// Tells when the app goes to the background.
  late final AppLifecycleListener _lifecycle;

  /// The fields got the stored texts once; after that they hold what is
  /// typed, whatever the street says.
  var _filled = false;

  @override
  void initState() {
    super.initState();
    // `listenManual` (not `ref.listen` in `build`): runs once now with the
    // current state (`fireImmediately`), then at each change, outside any
    // build, so it may set the fields' texts. Listening first keeps the
    // auto-disposed notifier alive for the `read` below.
    ref.listenManual(widget.provider, _follow, fireImmediately: true);
    _notifier = ref.read(widget.provider.notifier);
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
    final state = ref.watch(widget.provider);
    final name = widget.name;
    return SheetScaffold(
      children: switch (state) {
        HouseSheetLoading() => const [],
        HouseSheetGone() => [
          Text(
            widget.goneMessage,
            key: ValueKey('$name.gone'),
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
        HouseSheetShown(:final status) => [
          widget.title(state),
          if (status != null)
            _StatusControl(name: name, status: status, onSelected: _setStatus),
          ComeBackBlock(
            name: name,
            ticked: state.comeBack,
            enabled: state.canComeBack,
            onChanged: _setComeBack,
            hint: LimitedTextField(
              name: '$name.comeBackHint',
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
            name: '$name.note',
            controller: _note,
            focusNode: _noteFocus,
            limit: TextLimit.note,
            tooLongMessage: l10n.noteTooLong(TextLimit.note.max),
            label: l10n.noteLabel,
            maxLines: 4,
            helper: l10n.notePrivacyHint,
          ),
          ?widget.action,
          if (state.lastChange case final change?)
            Text(
              lastChangeText(l10n, change),
              key: ValueKey('$name.lastChange'),
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: colors.muted),
            ),
        ],
      },
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

/// « ○ À faire | ✓ Fait | ✗ Personne »: screen readers hear a group of
/// radio buttons named « Statut ».
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
      segments: [
        for (final option in VisitStatus.values)
          Segment(
            value: option,
            key: ValueKey('$name.status.${option.name}'),
            glyph: switch (option) {
              VisitStatus.toDo => StatusGlyphs.toDo,
              VisitStatus.done => StatusGlyphs.done,
              VisitStatus.nobodyHome => StatusGlyphs.nobodyHome,
            },
            label: switch (option) {
              VisitStatus.toDo => l10n.statusToDo,
              VisitStatus.done => l10n.statusDone,
              VisitStatus.nobodyHome => l10n.statusNobodyHome,
            },
          ),
      ],
    );
  }
}

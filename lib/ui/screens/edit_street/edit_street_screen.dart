import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/domain/street/street_part.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_notifier.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/keep_focus.dart';
import 'package:tournee_calendriers/ui/components/ok_button.dart';
import 'package:tournee_calendriers/ui/components/open_chevron.dart';
import 'package:tournee_calendriers/ui/components/street_part_words.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/building/building_grid_sheet.dart';
import 'package:tournee_calendriers/ui/screens/building/building_setup_sheet.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/add_numbers_sheet.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/edit_tiles.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/number_sheet.dart';
import 'package:tournee_calendriers/ui/screens/street_part/street_part_screen.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Modifier la rue », the edit mode of a street (PLAN §5.5,
/// `docs/mockups/Edit.dc.html`), opened by ✏ on the street screen: the
/// name, « Partie de la rue » (PLAN §5.15), the numbers of each side with
/// ✕, « + numéros » and « Supprimer la rue ». Works offline, but for
/// « Partie de la rue » of a street from the BAN, which reads its numbers.
///
/// Each change to the numbers is stored at once, with « Annuler » for 4 s.
/// The name is stored when the screen is left (« OK », ✕ or back), the
/// keyboard's « OK » is pressed, or the app goes to the background.
final class EditStreetScreen extends StatelessWidget {
  const EditStreetScreen({super.key, required this.streetId});

  /// Which street; null when the link named none.
  final StreetId? streetId;

  @override
  Widget build(BuildContext context) => switch (streetId) {
    final StreetId id => _EditScreen(streetId: id),
    null => Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: Text(AppLocalizations.of(context).screenEditStreet),
      ),
      body: const _GoneMessage(),
    ),
  };
}

final class _EditScreen extends ConsumerStatefulWidget {
  const _EditScreen({required this.streetId});

  final StreetId streetId;

  @override
  ConsumerState<_EditScreen> createState() => _EditScreenState();
}

/// A `State`: the screen owns the name field's text, the message saying
/// why a name was refused, and its undo snackbar ([UndoSnackBarHost]).
final class _EditScreenState extends ConsumerState<_EditScreen>
    with UndoSnackBarHost {
  final _name = TextEditingController();

  /// The name field's focus: the screen lets it go once the keyboard's
  /// « OK » kept the name ([_submitName]).
  final _nameFocus = FocusNode();

  /// Why the name typed was refused; cleared by the next edit.
  StreetNameFailure? _nameRefusal;

  /// Tells when the app goes to the background, as the house sheet does.
  late final AppLifecycleListener _lifecycle;

  /// « Partie de la rue » is reading the street's numbers: its row waits.
  var _readingPart = false;

  EditStreetNotifier get _notifier =>
      ref.read(editStreetProvider(widget.streetId).notifier);

  @override
  void initState() {
    super.initState();
    // `listenManual`: runs once the street is first read (and not at every
    // rebuild, as code in `build` would), to fill the name field. Later
    // renames do not overwrite what is being typed.
    ref.listenManual(editStreetProvider(widget.streetId), (previous, next) {
      if (previous is! EditStreetShown && next is EditStreetShown) {
        _name.text = next.name;
      }
    }, fireImmediately: true);
    // `onHide`: the app left the screen (home button, another app) and
    // Android may kill it without warning, so the name typed is stored now.
    // A refused name stays in the field with its message, for when the
    // person comes back.
    _lifecycle = AppLifecycleListener(onHide: () => unawaited(_keepName()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(editStreetProvider(widget.streetId));
    // `PopScope`: the back gesture leaves through [_leave] too, so the name
    // is kept (or refused) whichever way the screen is left.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: ScaffoldMessenger(
        key: messengerKey,
        child: Scaffold(
          appBar: AppBar(
            titleSpacing: 4,
            leading: CloseIconButton(
              key: const Key('edit.close'),
              tooltip: l10n.editStreetClose,
              onPressed: () => unawaited(_leave()),
            ),
            title: Text(l10n.screenEditStreet),
            actions: [
              if (state is EditStreetShown)
                OkButton(
                  key: const Key('edit.ok'),
                  onPressed: () => unawaited(_leave()),
                ),
              const SizedBox(width: 12),
            ],
          ),
          body: switch (state) {
            EditStreetLoading() => const SizedBox.shrink(),
            EditStreetGone() => const _GoneMessage(),
            EditStreetShown() => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NameField(
                  controller: _name,
                  focusNode: _nameFocus,
                  refusal: _nameRefusal,
                  onChanged: () {
                    if (_nameRefusal != null) {
                      setState(() => _nameRefusal = null);
                    }
                  },
                  onSubmitted: () => unawaited(_submitName()),
                ),
                _PartRow(
                  part: state.part,
                  reading: _readingPart,
                  onTap: () => unawaited(_openPart()),
                ),
                Expanded(
                  child: EditColumns(
                    state: state,
                    onEdit: (number) => unawaited(_openNumber(number)),
                    onRemove: (number) => unawaited(_remove(number)),
                    onAdd: () => unawaited(_addNumbers()),
                  ),
                ),
              ],
            ),
          },
          bottomNavigationBar: switch (state) {
            EditStreetShown(:final name) => _BottomActions(
              onDelete: () => unawaited(_deleteStreet(name)),
            ),
            EditStreetLoading() || EditStreetGone() => null,
          },
        ),
      ),
    );
  }

  /// Stores the name typed; returns false, showing why, when it is refused.
  Future<bool> _saveName() async {
    final refusal = await _notifier.renameStreet(_name.text);
    if (!mounted) return false;
    setState(() => _nameRefusal = refusal);
    return refusal == null;
  }

  /// The keyboard's « OK » on the name: a name kept closes the keyboard; a
  /// refused one keeps it open on the field ([keepFocusOnSubmit]).
  Future<void> _submitName() async {
    if (await _saveName()) _nameFocus.unfocus();
  }

  /// Stores the name typed when the field is on screen (not while the
  /// street is read, nor once it is gone); returns false when it is refused.
  Future<bool> _keepName() async =>
      ref.read(editStreetProvider(widget.streetId)) is! EditStreetShown ||
      await _saveName();

  /// « OK », ✕ or back: keeps the name, then goes back to the street. A
  /// refused name keeps the screen open, with the message under the field.
  Future<void> _leave() async {
    if (!await _keepName()) return;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.streetOf(widget.streetId));
    }
  }

  /// ✕ on a number: removed at once, or after a confirmation when it has
  /// marks, with « N° 3 supprimé [Annuler] ».
  Future<void> _remove(HouseNumber number) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    var outcome = await notifier.remove(number);
    if (outcome is EditNeedsConfirmation) {
      if (!mounted) return;
      hideUndo();
      final confirmed = await showConfirmDialog(
        context,
        name: 'edit.confirmRemove',
        title: l10n.confirmRemoveTitle(number.label),
        body: l10n.confirmRemoveBody,
        confirmLabel: l10n.delete,
      );
      if (!confirmed) return;
      outcome = await notifier.remove(number, confirmed: true);
    }
    if (outcome is EditApplied && mounted) {
      showUndo(
        message: l10n.numberRemoved(number.label),
        undoLabel: l10n.undo,
        onUndo: () => unawaited(notifier.undo()),
      );
    }
  }

  /// A tap on a number opens its sheet, then what the sheet asks for.
  Future<void> _openNumber(HouseNumber number) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    hideUndo();
    final exit = await showNumberSheet(context, widget.streetId, number);
    if (!mounted) return;
    switch (exit) {
      case null:
        return;
      case RenumberedExit(:final to):
        showUndo(
          message: l10n.numberRenamed(number.label, to.label),
          undoLabel: l10n.undo,
          onUndo: () => unawaited(notifier.undo()),
        );
      case DescribeBuildingExit():
        await showBuildingSetup(context, (
          street: widget.streetId,
          number: number,
        ));
      case OpenBuildingExit():
        final gridExit = await showBuildingGrid(context, (
          street: widget.streetId,
          number: number,
        ));
        if (gridExit == BuildingGridExit.backToHouse && mounted) {
          await _backToHouse(number);
        }
    }
  }

  /// « Changer en maison », chosen (and confirmed) in the grid.
  Future<void> _backToHouse(HouseNumber number) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    final outcome = await notifier.backToSingleHouse(number);
    if (outcome is EditApplied && mounted) {
      showUndo(
        message: l10n.backToHouseDone(number.label),
        undoLabel: l10n.undo,
        onUndo: () => unawaited(notifier.undo()),
      );
    }
  }

  /// « + numéros »: the sheet adds the numbers; they land on their side.
  Future<void> _addNumbers() {
    hideUndo();
    return showAddNumbers(context, widget.streetId);
  }

  /// The « Partie de la rue » row: reads what the part is chosen among,
  /// opens the screen, then gives the street the part chosen.
  Future<void> _openPart() async {
    if (_readingPart) return;
    final notifier = _notifier;
    hideUndo();
    setState(() => _readingPart = true);
    final reading = await notifier.readPart();
    if (!mounted) return;
    setState(() => _readingPart = false);
    switch (reading) {
      case PartReadRefused(:final problem):
        _sayPartProblem(problem);
      case PartReadable(:final request):
        final chosen = await showStreetPart(context, request);
        if (chosen != null && mounted) await _changePart(chosen);
    }
  }

  /// « Valider » on « Partie de la rue »: stores [part], asking first when
  /// numbers with marks would go to the Corbeille.
  Future<void> _changePart(StreetPart part) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    var outcome = await notifier.changePart(part);
    if (outcome case PartNeedsConfirmation(:final count)) {
      if (!mounted) return;
      final confirmed = await showConfirmDialog(
        context,
        name: 'edit.confirmPart',
        title: l10n.streetPartConfirmTitle,
        body: l10n.streetPartConfirmBody(count),
        confirmLabel: l10n.streetPartConfirmOk,
        destructive: true,
      );
      if (!confirmed) return;
      outcome = await notifier.changePart(part, confirmed: true);
    }
    if (outcome case PartRefused(:final problem) when mounted) {
      _sayPartProblem(problem);
    }
  }

  /// Why « Partie de la rue » did not open or store its part. A street gone
  /// says so in place of the screen already.
  void _sayPartProblem(PartProblem problem) {
    final l10n = AppLocalizations.of(context);
    switch (problem) {
      case PartProblem.offline:
        showMessage(l10n.streetPartNoNetwork);
      case PartProblem.unavailable:
        showMessage(l10n.streetPartUnavailable);
      case PartProblem.gone:
        break;
    }
  }

  /// « Supprimer la rue », after a confirmation: the street goes to the
  /// Corbeille, and the app goes back to Accueil, where it no longer
  /// shows.
  Future<void> _deleteStreet(String name) async {
    final l10n = AppLocalizations.of(context);
    final notifier = _notifier;
    hideUndo();
    final confirmed = await showConfirmDialog(
      context,
      name: 'edit.confirmDelete',
      title: l10n.confirmDeleteStreetTitle,
      body: l10n.confirmDeleteStreetBody(name),
      confirmLabel: l10n.delete,
    );
    if (!confirmed) return;
    if (await notifier.deleteStreet() && mounted) context.go(AppRoutes.home);
  }
}

/// « Nom de la rue » and its field; the message under it when the name
/// typed is refused.
final class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.refusal,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final StreetNameFailure? refusal;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final refusal = this.refusal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        10,
        AppSizes.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          // `MergeSemantics`: TalkBack names the field « Nom de la rue ».
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(
                  l10n.streetNameLabel,
                  style: AppTextStyles.small.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextField(
                  key: const Key('edit.name'),
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  style: AppTextStyles.streetName.copyWith(color: colors.ink),
                  onChanged: (_) => onChanged(),
                  focusNode: focusNode,
                  onEditingComplete: keepFocusOnSubmit,
                  onSubmitted: (_) => onSubmitted(),
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AppSizes.fieldRadius),
                      ),
                      borderSide: BorderSide(
                        color: colors.ink,
                        width: AppSizes.borderWidth,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (refusal != null)
            Semantics(
              liveRegion: true,
              child: Text(
                switch (refusal) {
                  StreetNameFailure.blank => l10n.streetNameBlank,
                  StreetNameFailure.tooLong => l10n.streetNameTooLong(
                    StreetName.maxLength,
                  ),
                },
                key: const Key('edit.nameRefusal'),
                style: AppTextStyles.small.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// « Partie de la rue » and the part held (« Impairs 1–57 · pairs 2–30 »)
/// under the name, with ›: opens « Partie de la rue » (Edit mockup). While
/// the street's numbers are read, a spinner takes the place of ›.
final class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.part,
    required this.reading,
    required this.onTap,
  });

  final StreetPart part;
  final bool reading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final text = streetPartText(l10n, part);
    const radius = BorderRadius.all(Radius.circular(AppSizes.fieldRadius));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.gutter,
        10,
        AppSizes.gutter,
        0,
      ),
      child: Semantics(
        button: true,
        label: l10n.streetPartRowSemantics(text),
        excludeSemantics: true,
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: colors.line, width: AppSizes.borderWidth),
          ),
          child: InkWell(
            key: const Key('edit.part'),
            customBorder: const RoundedRectangleBorder(borderRadius: radius),
            onTap: reading ? null : onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.fieldHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.fieldPadding,
                  6,
                  12,
                  6,
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.streetPartTitle,
                            style: AppTextStyles.small.copyWith(
                              color: colors.muted,
                            ),
                          ),
                          Text(
                            text,
                            key: const Key('edit.partText'),
                            style: AppTextStyles.body.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reading)
                      SizedBox.square(
                        dimension: AppSizes.smallIcon,
                        child: CircularProgressIndicator(
                          key: const Key('edit.partReading'),
                          strokeWidth: 2,
                          color: colors.muted,
                        ),
                      )
                    else
                      OpenChevron(
                        height: AppSizes.titleChevron,
                        color: colors.muted,
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

/// The white bar at the bottom: « Supprimer la rue », the whole width
/// (Edit mockup).
final class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      // `minimum`: 24 dp under the button, or the system's gesture bar when
      // it is taller, not both.
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            12,
            AppSizes.gutter,
            0,
          ),
          child: SecondaryButton(
            key: const Key('edit.deleteStreet'),
            label: l10n.deleteStreetAction,
            compact: true,
            destructive: true,
            onPressed: onDelete,
          ),
        ),
      ),
    );
  }
}

final class _GoneMessage extends StatelessWidget {
  const _GoneMessage();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        AppLocalizations.of(context).streetGone,
        key: const Key('edit.gone'),
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.of(context).muted),
      ),
    ),
  );
}

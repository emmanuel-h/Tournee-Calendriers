import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_notifier.dart';
import 'package:tournee_calendriers/presentation/edit_street/edit_street_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/building_icon.dart';
import 'package:tournee_calendriers/ui/components/keep_focus.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/number_messages.dart';
import 'package:tournee_calendriers/ui/screens/street/marks_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// How the number sheet was left, when the edit mode has something to do
/// next. `sealed`: the edit mode handles each case.
sealed class NumberSheetExit {
  const NumberSheetExit();
}

/// The house now has the number [to]: « N° 3 → 3bis [Annuler] ».
final class RenumberedExit extends NumberSheetExit {
  const RenumberedExit(this.to);

  final HouseNumber to;
}

/// « Transformer en immeuble… » or « Modifier les étages »: « Décrire
/// l'immeuble » opens next.
final class DescribeBuildingExit extends NumberSheetExit {
  const DescribeBuildingExit();
}

/// « Ajuster les portes »: the screen that adjusts the building floor by
/// floor opens next.
final class AdjustDoorsExit extends NumberSheetExit {
  const AdjustDoorsExit();
}

/// « Redevenir une maison »: the edit mode asks first when doors have
/// marks.
final class BackToHouseExit extends NumberSheetExit {
  const BackToHouseExit();
}

/// Opens the sheet of [number] in the edit mode of [street] (PLAN §5.5:
/// tap a number). Returns what to do next, or null.
///
/// The sheet closes before the next step opens (« Décrire l'immeuble », a
/// confirmation), rather than stacking two sheets.
Future<NumberSheetExit?> showNumberSheet(
  BuildContext context,
  StreetId street,
  HouseNumber number,
) => showAppBottomSheet<NumberSheetExit>(
  context: context,
  builder: (_) => NumberSheet(streetId: street, number: number),
);

/// « 3 Rue des Lilas », the « Numéro » field with « Changer le numéro »,
/// then *Transformer en immeuble…* for a house, or « Ajuster les portes »,
/// « Modifier les étages » and « Redevenir une maison » for a building.
final class NumberSheet extends ConsumerStatefulWidget {
  const NumberSheet({super.key, required this.streetId, required this.number});

  final StreetId streetId;
  final HouseNumber number;

  @override
  ConsumerState<NumberSheet> createState() => _NumberSheetState();
}

/// A `State`: the sheet keeps the text typed, the message saying why it
/// was refused, and what it showed last.
final class _NumberSheetState extends ConsumerState<NumberSheet> {
  late final _field = TextEditingController(text: widget.number.label);

  /// Why the last « Changer le numéro » was refused; cleared by the next
  /// edit of the field.
  String? _refusal;

  /// What the sheet showed last. Once the number is changed the street no
  /// longer shows the old one: the sheet keeps showing this while it slides
  /// away, instead of « Ce numéro n'est plus dans cette rue. ».
  (String, EditTile)? _shown;
  var _leaving = false;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(editStreetProvider(widget.streetId));
    if (!_leaving) {
      _shown = switch (state) {
        EditStreetShown() => switch (state.tileOf(widget.number)) {
          final EditTile tile => (state.name, tile),
          null => null,
        },
        EditStreetLoading() || EditStreetGone() => null,
      };
    }
    final shown = _shown;
    if (shown == null) {
      return SheetScaffold(
        children: [
          Text(
            l10n.houseGone,
            key: const Key('number.gone'),
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
      );
    }
    final (streetName, tile) = shown;
    void leave(NumberSheetExit exit) => Navigator.of(context).pop(exit);
    return SheetScaffold(
      spacing: 14,
      children: [
        MarksSheetTitle(
          name: 'number',
          big: tile.number.label,
          beside: streetName,
        ),
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                l10n.numberLabel,
                style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
              ),
              TextField(
                key: const Key('number.field'),
                controller: _field,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
                onChanged: (_) {
                  if (_refusal != null) setState(() => _refusal = null);
                },
                onEditingComplete: keepFocusOnSubmit,
                onSubmitted: (_) => unawaited(_renumber()),
              ),
            ],
          ),
        ),
        if (_refusal case final refusal?)
          Semantics(
            liveRegion: true,
            child: Text(
              refusal,
              key: const Key('number.refusal'),
              style: AppTextStyles.small.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        PrimaryButton(
          key: const Key('number.renumber'),
          label: l10n.renumberAction,
          compact: true,
          onPressed: () => unawaited(_renumber()),
        ),
        if (tile.isBuilding) ...[
          SecondaryButton(
            key: const Key('number.adjustDoors'),
            label: l10n.adjustDoorsAction,
            compact: true,
            strong: true,
            onPressed: () => leave(const AdjustDoorsExit()),
          ),
          SecondaryButton(
            key: const Key('number.editFloors'),
            label: l10n.editFloors,
            compact: true,
            leading: const BuildingIcon(size: AppSizes.smallIcon),
            onPressed: () => leave(const DescribeBuildingExit()),
          ),
          SecondaryButton(
            key: const Key('number.backToHouse'),
            label: l10n.backToHouseAction,
            compact: true,
            onPressed: () => leave(const BackToHouseExit()),
          ),
        ] else
          SecondaryButton(
            key: const Key('number.toBuilding'),
            label: l10n.transformToBuilding,
            compact: true,
            leading: const BuildingIcon(size: AppSizes.smallIcon),
            onPressed: () => leave(const DescribeBuildingExit()),
          ),
      ],
    );
  }

  /// « Changer le numéro »: closes the sheet once the house has its new
  /// number (or when the number typed is the same); otherwise says why.
  Future<void> _renumber() async {
    final l10n = AppLocalizations.of(context);
    final text = _field.text.trim();
    final outcome = await ref
        .read(editStreetProvider(widget.streetId).notifier)
        .renumber(widget.number, text);
    if (!mounted) return;
    switch (outcome) {
      case Renumbered(:final newNumber):
        setState(() => _leaving = true);
        Navigator.of(context).pop(RenumberedExit(newNumber));
      case RenumberUnchanged():
        Navigator.of(context).pop();
      case RenumberInvalid(:final reason):
        setState(() => _refusal = houseNumberMessage(l10n, text, reason));
      case RenumberTaken(:final number):
        setState(() => _refusal = l10n.renumberTaken(number.label));
      case RenumberInCorbeille(:final number):
        setState(() => _refusal = l10n.renumberInCorbeille(number.label));
      case RenumberFailed():
        setState(() => _refusal = l10n.houseGone);
    }
  }
}

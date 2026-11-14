import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/round/round_id.dart';
import 'package:tournee_calendriers/domain/street/building/dwelling.dart';
import 'package:tournee_calendriers/domain/street/house_number.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_notifier.dart';
import 'package:tournee_calendriers/presentation/street/street_view_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/amber_note.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/building/building_grid_sheet.dart';
import 'package:tournee_calendriers/ui/screens/street/street_tiles.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The street in « Touchez la maison oubliée » (PLAN §5.20, mockup
/// MarkForgottenStreet), pushed by « Quelle maison ? »: the street's name
/// over « Villefranche-sur-Saône · 31/42 », the amber line, then its houses
/// odd and even, those ✓ or ⊘ faded (a tap on one says « N° 9 : déjà
/// marquée ✓. »). One tap on another marks it ✓ with no tournée on, the
/// only exception to #122, counted on the tournée [round]; the screen then
/// pops what was marked (« N° 3 rue des Lilas marquée ✓. »). A building
/// opens its doors in the same mode. Offline too.
final class ForgottenStreetScreen extends ConsumerStatefulWidget {
  const ForgottenStreetScreen({
    super.key,
    required this.round,
    required this.street,
  });

  final RoundId round;
  final StreetId street;

  @override
  ConsumerState<ForgottenStreetScreen> createState() => _ForgottenStreetState();
}

/// A `State` for the screen's own snackbars ([UndoSnackBarHost]), which
/// go with it, and to mark only once.
final class _ForgottenStreetState extends ConsumerState<ForgottenStreetScreen>
    with UndoSnackBarHost {
  /// A tap is being marked: the others wait.
  var _marking = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // `ref.watch`: the street as the phone has it, a teammate's marks
    // included.
    final state = ref.watch(streetProvider(widget.street));
    return ScaffoldMessenger(
      key: messengerKey,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
          titleSpacing: 4,
          title: switch (state) {
            StreetShown(
              :final name,
              :final commune,
              :final done,
              :final total,
            ) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 2,
                children: [
                  Text(name),
                  Text(
                    l10n.forgottenStreetSubtitle(commune, done, total),
                    key: const Key('forgotten.subtitle'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small.copyWith(color: colors.muted),
                  ),
                ],
              ),
            StreetLoading() || StreetGone() => Text(l10n.screenStreet),
          },
        ),
        body: SafeArea(
          top: false,
          child: switch (state) {
            StreetLoading() => const SizedBox.shrink(),
            StreetGone() => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l10n.streetGone,
                  key: const Key('forgotten.gone'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: colors.muted),
                ),
              ),
            ),
            final StreetShown state => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.gutter,
                    0,
                    AppSizes.gutter,
                    12,
                  ),
                  child: AmberNote(
                    key: const Key('forgotten.info'),
                    l10n.forgottenStreetInfo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.gutter,
                  ),
                  child: Row(
                    spacing: AppSizes.columnGap,
                    children: [
                      if (state.columns != StreetColumns.evenOnly)
                        Expanded(
                          child: SectionHeader(
                            l10n.oddSide,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      if (state.columns != StreetColumns.oddOnly)
                        Expanded(
                          child: SectionHeader(
                            l10n.evenSide,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreetTiles(
                    state: state,
                    showHint: false,
                    fadeVisited: true,
                    onTap: (number) => unawaited(_tapHouse(state, number)),
                    onOpenBuilding: (number) => unawaited(
                      showForgottenDoorGrid(
                        context,
                        (street: widget.street, number: number),
                        onDoor: (door) => unawaited(_mark(number, door: door)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }

  /// A tap on the house [number]: « déjà marquée » when it is ✓ or ⊘,
  /// otherwise marked.
  Future<void> _tapHouse(StreetShown state, HouseNumber number) async {
    final l10n = AppLocalizations.of(context);
    final mark = [
      ...state.odd,
      ...state.even,
    ].firstWhere((tile) => tile.number == number).mark;
    switch (mark) {
      case DoneMark():
        showMessage(l10n.forgottenHouseDone(number.label));
      case RefusedMark():
        showMessage(l10n.forgottenHouseRefused(number.label));
      case ToDoMark() ||
          NobodyHomeMark() ||
          ComeBackMark() ||
          PartialBuildingMark():
        await _mark(number);
    }
  }

  /// Marks the house [number] (its door [door] in a building) ✓ for the
  /// tournée, then leaves with what was marked; a house marked meanwhile
  /// says so. Gone, or nothing left to mark: back to « Quelle maison ? ».
  Future<void> _mark(HouseNumber number, {DwellingKey? door}) async {
    if (_marking) return;
    _marking = true;
    final l10n = AppLocalizations.of(context);
    final state = ref.read(streetProvider(widget.street));
    final street = state is StreetShown ? _inSentence(state.name) : '';
    final outcome = await ref
        .read(collecteProvider.notifier)
        .markForgottenHouse(
          widget.round,
          street: widget.street,
          number: number,
          door: door,
        );
    _marking = false;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    switch (outcome) {
      case ForgottenMarkOutcome.marked:
        navigator.pop(
          door == null
              ? l10n.forgottenHouseMarked(number.label, street)
              : l10n.forgottenDoorMarked(door.label.text, number.label, street),
        );
      case ForgottenMarkOutcome.alreadyVisited:
        showMessage(
          door == null
              ? l10n.forgottenHouseDone(number.label)
              : l10n.forgottenDoorDone(door.label.text),
        );
      case ForgottenMarkOutcome.nothingToMark || ForgottenMarkOutcome.houseGone:
        navigator.pop();
    }
  }

  /// The street's name inside a sentence: « Rue des Lilas » becomes « rue
  /// des Lilas » (« N° 3 rue des Lilas marquée ✓. »).
  static String _inSentence(String name) =>
      name.isEmpty ? name : name[0].toLowerCase() + name.substring(1);
}

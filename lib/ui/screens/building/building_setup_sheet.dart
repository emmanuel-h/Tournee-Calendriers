import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/building/building_plan.dart';
import 'package:tournee_calendriers/domain/street/building/staircase_name.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_notifier.dart';
import 'package:tournee_calendriers/presentation/building/building_setup_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/building/floor_names.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens « Décrire l'immeuble » (PLAN §5.7,
/// `docs/mockups/BuildingSetup.dc.html`) for [house]: from « Transformer en
/// immeuble… » on a house, prefilled from the building by « Modifier les
/// étages ». Returns true once « Valider » laid the building out.
Future<bool> showBuildingSetup(
  BuildContext context,
  BuildingSetupKey house,
) async =>
    await showAppBottomSheet<bool>(
      context: context,
      builder: (_) => BuildingSetupSheet(house: house),
    ) ??
    false;

/// Steppers « Escaliers », « Étages », « Portes par étage », the label
/// style, the preview and « Valider ». A step the domain refuses leaves
/// the answers as they were and says why, above the preview.
final class BuildingSetupSheet extends ConsumerWidget {
  const BuildingSetupSheet({super.key, required this.house});

  final BuildingSetupKey house;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final provider = buildingSetupProvider(house);
    final state = ref.watch(provider);
    final setup = ref.read(provider.notifier);
    return SheetScaffold(
      spacing: 6,
      children: switch (state) {
        BuildingSetupLoading() => const [],
        BuildingSetupGone() => [
          Text(
            l10n.houseGone,
            key: const Key('setup.gone'),
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
        BuildingSetupShown(:final plan) => [
          Semantics(
            header: true,
            child: Text(
              l10n.buildingSetupTitle,
              style: AppTextStyles.title.copyWith(color: colors.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${state.number.label} ${state.streetName}',
              style: AppTextStyles.body.copyWith(color: colors.muted),
            ),
          ),
          _StepperRow(
            name: 'staircases',
            label: l10n.setupStaircases,
            value: '${plan.staircaseCount}',
            fewer: l10n.setupFewerStaircases,
            more: l10n.setupMoreStaircases,
            onFewer: setup.removeStaircase,
            onMore: setup.addStaircase,
          ),
          if (state.offersSameForEach)
            _SameForEachBox(
              value: state.sameForEach,
              onChanged: (same) => setup.setSameForEach(same: same),
            ),
          if (state.stepsEachStaircase)
            for (final (index, staircase) in plan.staircases.indexed)
              ..._staircaseSteppers(
                l10n,
                setup,
                staircase,
                name: StaircaseName.at(index),
              )
          else
            ..._staircaseSteppers(l10n, setup, plan.staircases.first),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              l10n.setupLabelStyle,
              style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
            ),
          ),
          SegmentedChoice<DoorLabelStyle>(
            groupLabel: l10n.setupLabelStyle,
            selected: plan.style,
            onSelected: setup.setStyle,
            height: AppSizes.labelStyleHeight,
            textStyle: AppTextStyles.segment,
            segments: [
              for (final style in DoorLabelStyle.values)
                Segment(
                  value: style,
                  key: ValueKey('setup.style.${style.name}'),
                  label: switch (style) {
                    DoorLabelStyle.floorAndNumber => l10n.labelStyleNumber,
                    DoorLabelStyle.floorAndLetter => l10n.labelStyleLetter,
                    DoorLabelStyle.free => l10n.labelStyleFree,
                  },
                ),
            ],
          ),
          if (state.refusal case final refusal?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              // `liveRegion`: TalkBack reads the refusal as soon as it
              // shows.
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _refusalText(l10n, refusal),
                  key: const Key('setup.refusal'),
                  style: AppTextStyles.small.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          _Preview(preview: state.preview),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: PrimaryButton(
              key: const Key('setup.validate'),
              label: l10n.setupValidate,
              onPressed: () => unawaited(_validate(context, setup)),
            ),
          ),
        ],
      },
    );
  }

  /// « Étages » and « Portes par étage » of [staircase]: of the staircase
  /// [name], under its header « ESC. B », or of every staircase alike when
  /// [name] is null.
  static List<Widget> _staircaseSteppers(
    AppLocalizations l10n,
    BuildingSetupNotifier setup,
    StaircasePlan staircase, {
    StaircaseName? name,
  }) {
    final prefix = name == null ? '' : '${name.letter}.';
    return [
      if (name != null)
        SectionHeader(
          l10n.setupStaircaseHeader(name.letter),
          padding: const EdgeInsets.only(top: 12),
        ),
      _StepperRow(
        name: '${prefix}floors',
        label: l10n.setupFloors,
        staircase: name,
        value: switch (staircase.topFloor) {
          null => l10n.setupFloorsUnknown,
          0 => l10n.floorGround,
          final top => l10n.setupFloorsRange(floorName(l10n, top)),
        },
        fewer: l10n.setupFewerFloors,
        more: l10n.setupMoreFloors,
        onFewer: () => setup.removeFloor(staircase: name),
        onMore: () => setup.addFloor(staircase: name),
      ),
      _StepperRow(
        name: '${prefix}doors',
        label: l10n.setupDoorsPerFloor,
        staircase: name,
        value: '${staircase.doorsPerFloor}',
        fewer: l10n.setupFewerDoors,
        more: l10n.setupMoreDoors,
        onFewer: () => setup.removeDoor(staircase: name),
        onMore: () => setup.addDoor(staircase: name),
      ),
    ];
  }

  /// « Valider »: lays the building out and closes the sheet, after asking
  /// when marked doors would be dropped.
  static Future<void> _validate(
    BuildContext context,
    BuildingSetupNotifier setup,
  ) async {
    var outcome = await setup.validate();
    if (outcome case SetupNeedsConfirmation(:final markedDoors)) {
      if (!context.mounted) return;
      final confirmed = await _confirmDrop(context, markedDoors);
      if (!confirmed) return;
      outcome = await setup.validate(confirmed: true);
    }
    // When the house went meanwhile (`SetupFailed`), the sheet already
    // says so and stays.
    if (outcome is SetupLaidOut && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  static Future<bool> _confirmDrop(BuildContext context, int doors) {
    final l10n = AppLocalizations.of(context);
    return showConfirmDialog(
      context,
      name: 'setup.confirm',
      title: l10n.setupConfirmTitle,
      body: l10n.setupConfirmBody(doors),
      confirmLabel: l10n.setupConfirmAction,
    );
  }

  static String _refusalText(
    AppLocalizations l10n,
    BuildingPlanFailure refusal,
  ) => switch (refusal) {
    BuildingPlanFailure.noStaircase => l10n.setupNoStaircase,
    BuildingPlanFailure.tooManyStaircases => l10n.setupTooManyStaircases(
      StaircaseName.maxCount,
    ),
    BuildingPlanFailure.belowGroundFloor => l10n.setupBelowGroundFloor,
    BuildingPlanFailure.tooManyFloors => l10n.setupTooManyFloors(
      BuildingPlan.maxTopFloor,
    ),
    BuildingPlanFailure.noDoor => l10n.setupNoDoor,
    BuildingPlanFailure.tooManyDoorsForLetters =>
      l10n.setupTooManyDoorsForLetters(DoorLabelStyle.letterCount),
    BuildingPlanFailure.tooManyDwellings => l10n.setupTooManyDwellings(
      BuildingPlan.maxDwellings,
    ),
  };
}

/// « Escaliers   (−) 2 (+) », over a thin divider.
final class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.name,
    required this.label,
    this.staircase,
    required this.value,
    required this.fewer,
    required this.more,
    required this.onFewer,
    required this.onMore,
  });

  /// Names the parts for tests: `setup.<name>.value`, `.fewer`, `.more`.
  final String name;
  final String label;

  /// The staircase the row steps alone, which screen readers then name
  /// (« Étages, escalier B »); null for every staircase.
  final StaircaseName? staircase;
  final String value;

  /// What screen readers hear for (−) and (+).
  final String fewer;
  final String more;
  final VoidCallback onFewer;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    String spoken(String text) => switch (staircase) {
      null => text,
      final name => l10n.setupForStaircase(text, name.letter),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.stepperRowHeight),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.fieldLabel.copyWith(
                color: colors.ink,
                fontSize: AppTextStyles.body.fontSize,
              ),
            ),
          ),
          _StepButton(
            key: ValueKey('setup.$name.fewer'),
            sign: '−',
            semanticsLabel: spoken(fewer),
            onPressed: onFewer,
          ),
          // `liveRegion`: the new value is read after each tap.
          Semantics(
            liveRegion: true,
            label: l10n.setupStepperSemantics(spoken(label), value),
            excludeSemantics: true,
            // A fixed width keeps the (−) buttons of the three rows in
            // line; a wider value (« RdC–50e ») shrinks to fit.
            child: SizedBox(
              width: AppSizes.stepperValueWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  key: ValueKey('setup.$name.value'),
                  style: AppTextStyles.stepperValue.copyWith(color: colors.ink),
                ),
              ),
            ),
          ),
          _StepButton(
            key: ValueKey('setup.$name.more'),
            sign: '+',
            semanticsLabel: spoken(more),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

/// « ☐ Même chose pour chaque escalier », over a thin divider like the
/// steppers.
final class _SameForEachBox extends StatelessWidget {
  const _SameForEachBox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      // A `CheckboxListTile` is one tap target of 56 dp at least, box and
      // text alike, and screen readers hear « case cochée » with the text.
      child: CheckboxListTile(
        key: const Key('setup.sameForEach'),
        value: value,
        // `onChanged` gives a `bool?`: null only for a three-state box.
        onChanged: (checked) => onChanged(checked ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: 12,
        title: Text(
          AppLocalizations.of(context).setupSameForEach,
          style: AppTextStyles.body.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}

/// A round (−) or (+) button of 48 dp.
final class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.sign,
    required this.semanticsLabel,
    required this.onPressed,
  });

  final String sign;
  final String semanticsLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: AppSizes.stepperButton,
        child: Material(
          color: colors.surface,
          shape: CircleBorder(
            side: BorderSide(color: colors.line, width: AppSizes.borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Text(
                sign,
                style: AppTextStyles.stepperSign.copyWith(color: colors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « APERÇU · 48 LOGEMENTS », « Esc. A et B : RdC 01–04, 1er 11–14 … 5e
/// 51–54 » (or one line per staircase when they differ, so a range such as
/// « 01–02 » is never split across two lines), and what can be adjusted
/// later.
final class _Preview extends StatelessWidget {
  const _Preview({required this.preview});

  final BuildingPreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final line = [
      for (final part in preview.parts)
        '${preview.namesStaircases ? _staircases(l10n, part.staircases) : ''}'
            '${_floors(l10n, part)}',
    ].join('\n');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.ground,
        borderRadius: BorderRadius.circular(AppSizes.segmentRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: [
          SectionHeader(
            l10n.setupPreviewTitle(preview.dwellings),
            padding: EdgeInsets.zero,
          ),
          Text(
            line,
            key: const Key('setup.preview'),
            style: AppTextStyles.previewLine.copyWith(color: colors.ink),
          ),
          Text(
            l10n.setupPreviewHint,
            style: AppTextStyles.helper.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// « Esc. B : », « Esc. A et B : » or « Esc. A à C : ».
String _staircases(AppLocalizations l10n, List<StaircaseName> names) =>
    switch (names) {
      [final only] => l10n.setupPreviewStaircaseOne(only.letter),
      [final first, final last] => l10n.setupPreviewStaircasesTwo(
        first.letter,
        last.letter,
      ),
      _ => l10n.setupPreviewStaircasesMany(
        names.first.letter,
        names.last.letter,
      ),
    };

/// « RdC 01–04, 1er 11–14 … 5e 51–54 »: the floors of [part], « … » where
/// some are left out; a floor of one door shows its label alone.
String _floors(AppLocalizations l10n, PreviewPart part) {
  final floors = [
    for (final floor in part.floors)
      '${floorName(l10n, floor.level)} '
          '${floor.first == floor.last ? floor.first : l10n.setupPreviewRange(floor.first, floor.last)}',
  ];
  if (!part.skipsFloors) return floors.join(', ');
  return '${floors.sublist(0, floors.length - 1).join(', ')} … ${floors.last}';
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/shared/insee_code.dart';
import 'package:tournee_calendriers/domain/street/house_numbers_input.dart';
import 'package:tournee_calendriers/domain/street/street_name.dart';
import 'package:tournee_calendriers/presentation/manual_street/manual_street_notifier.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/segmented_choice.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/communes/commune_picker_field.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/number_messages.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Rue à la main » (PLAN §5.5, Manual mockup): a street the map does
/// not have (a private road, a new estate), typed in with its range of
/// numbers. Works offline; the street has no road on the map.
///
/// « Ajouter la rue » gives it to the member who types it and goes back,
/// saying « « Chemin des Vignes » ajoutée à vos rues. ».
final class ManualStreetScreen extends ConsumerWidget {
  const ManualStreetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(manualStreetProvider);
    // `ref.read` for the intents: they are sent, never watched.
    final form = ref.read(manualStreetProvider.notifier);
    final preview = state.preview;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.manualTitle), titleSpacing: 0),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                children: [
                  _Labelled(
                    label: l10n.manualName,
                    child: TextField(
                      key: const Key('manual.name'),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.ink,
                      ),
                      onChanged: form.setName,
                      decoration: InputDecoration(
                        errorText: switch (state.nameProblem) {
                          StreetNameFailure.tooLong => l10n.streetNameTooLong(
                            StreetName.maxLength,
                          ),
                          // A blank name only keeps the button disabled.
                          StreetNameFailure.blank || null => null,
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Labelled(
                    label: l10n.manualCommune,
                    child: state.communes.isEmpty
                        ? _CommuneSearch(state: state, form: form)
                        : DropdownButtonFormField<InseeCode>(
                            key: const Key('manual.commune'),
                            initialValue: state.commune?.inseeCode,
                            // A long name is cut rather than overflowing.
                            isExpanded: true,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: colors.ink,
                            ),
                            items: [
                              for (final commune in state.communes)
                                DropdownMenuItem(
                                  value: commune.inseeCode,
                                  child: Text(
                                    commune.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (commune) {
                              if (commune != null) form.chooseCommune(commune);
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: _Labelled(
                          label: l10n.manualFrom,
                          child: _NumberField(
                            key: const Key('manual.from'),
                            onChanged: form.setFrom,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _Labelled(
                          label: l10n.manualTo,
                          child: _NumberField(
                            key: const Key('manual.to'),
                            onChanged: form.setTo,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedChoice<Sides>(
                    key: const Key('manual.sides'),
                    groupLabel: l10n.manualSides,
                    height: AppSizes.minTapTarget,
                    selected: state.sides,
                    onSelected: form.setSides,
                    segments: [
                      Segment(
                        value: Sides.both,
                        label: l10n.manualBothSides,
                        key: const Key('manual.sides.both'),
                      ),
                      Segment(
                        value: Sides.odd,
                        label: l10n.manualOddSide,
                        key: const Key('manual.sides.odd'),
                      ),
                      Segment(
                        value: Sides.even,
                        label: l10n.manualEvenSide,
                        key: const Key('manual.sides.even'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Labelled(
                    label: l10n.manualExtras,
                    child: TextField(
                      key: const Key('manual.extras'),
                      // Numbers and « bis »: no spelling help, which would
                      // « correct » 12bis.
                      autocorrect: false,
                      enableSuggestions: false,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.ink,
                      ),
                      onChanged: form.setExtras,
                      decoration: InputDecoration(
                        hintText: l10n.numbersPlaceholder,
                        helperText: l10n.manualExtrasHelper,
                        helperStyle: AppTextStyles.helper.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  switch (preview) {
                    NothingTyped() => const SizedBox.shrink(),
                    NumbersRefused(:final failure) => Semantics(
                      // `liveRegion`: TalkBack reads the message as it
                      // shows.
                      liveRegion: true,
                      child: Text(
                        numbersMessage(l10n, failure),
                        key: const Key('manual.refusal'),
                        style: AppTextStyles.small.copyWith(
                          color: colors.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    NumbersPreviewed(:final numbers) => Container(
                      key: const Key('manual.preview'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border.all(color: colors.divider),
                        borderRadius: BorderRadius.circular(
                          AppSizes.segmentRadius,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 4,
                        children: [
                          SectionHeader(
                            l10n.numbersPreviewTitle(numbers.length),
                            padding: EdgeInsets.zero,
                          ),
                          Text(
                            shortNumberList(numbers),
                            style: AppTextStyles.previewLine.copyWith(
                              color: colors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  },
                  const SizedBox(height: 12),
                  Text(
                    l10n.manualOffline,
                    style: AppTextStyles.small.copyWith(color: colors.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: PrimaryButton(
                key: const Key('manual.add'),
                label: l10n.manualAdd,
                onPressed: state.canAdd
                    ? () => unawaited(_add(context, form))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Adds the street, then goes back to the map and says so.
  static Future<void> _add(
    BuildContext context,
    ManualStreetNotifier form,
  ) async {
    // Read before the `await`: the context must not be used across it.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final name = await form.add();
    if (name == null || !context.mounted) return;
    showMessageSnackBar(messenger, message: l10n.manualAdded(name));
    context.pop();
  }
}

/// A field with its label above it (« Nom de la rue »), said together by
/// screen readers.
final class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          label,
          style: AppTextStyles.fieldLabel.copyWith(
            color: AppColors.of(context).ink,
          ),
        ),
        child,
      ],
    ),
  );
}

/// « Du n° », « Au n° »: digits only.
final class _NumberField extends StatelessWidget {
  const _NumberField({super.key, required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    textInputAction: TextInputAction.next,
    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.of(context).ink),
    onChanged: onChanged,
  );
}

/// A tournée with neither commune nor street: the commune is searched
/// (network), as on the « Liste » tab; the one found shows under it.
final class _CommuneSearch extends StatelessWidget {
  const _CommuneSearch({required this.state, required this.form});

  final ManualStreetState state;
  final ManualStreetNotifier form;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final commune = state.commune;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        if (commune == null)
          Text(
            l10n.manualNoCommune,
            style: AppTextStyles.small.copyWith(color: colors.muted),
          )
        else
          Text(
            commune.name,
            key: const Key('manual.communeFound'),
            style: AppTextStyles.bodyLarge.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        CommunePickerField(
          onPick: (option) => form.pickCommune(option.commune),
        ),
      ],
    );
  }
}

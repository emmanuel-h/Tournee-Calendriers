import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/edit_street/add_numbers_notifier.dart';
import 'package:tournee_calendriers/presentation/edit_street/add_numbers_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/edit_street/number_messages.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens « Ajouter des numéros » (PLAN §5.5,
/// `docs/mockups/Numbers.dc.html`) over the edit mode of [street]. It
/// closes once « Ajouter » changed the street.
Future<void> showAddNumbers(BuildContext context, StreetId street) =>
    showAppBottomSheet<void>(
      context: context,
      builder: (_) => AddNumbersSheet(streetId: street),
    );

/// The « Numéros » field (`12bis, 21-25`), its live preview, and
/// « Ajouter ». The new numbers land on their side by themselves.
final class AddNumbersSheet extends ConsumerWidget {
  const AddNumbersSheet({super.key, required this.streetId});

  final StreetId streetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final provider = addNumbersProvider(streetId);
    final state = ref.watch(provider);
    final sheet = ref.read(provider.notifier);
    return SheetScaffold(
      spacing: 16,
      children: switch (state) {
        AddNumbersLoading() => const [],
        AddNumbersGone() => [
          Text(
            l10n.streetGone,
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
        AddNumbersShown(:final streetName, :final preview) => [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 2,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.addNumbersTitle,
                  style: AppTextStyles.title.copyWith(color: colors.ink),
                ),
              ),
              Text(
                streetName,
                style: AppTextStyles.body.copyWith(color: colors.muted),
              ),
            ],
          ),
          _NumbersField(
            onChanged: sheet.type,
            onSubmitted: () => unawaited(_add(context, sheet)),
          ),
          switch (preview) {
            NothingTyped() => const SizedBox.shrink(),
            NumbersRefused(:final failure) => Semantics(
              // `liveRegion`: TalkBack reads the message as it shows.
              liveRegion: true,
              child: Text(
                numbersMessage(l10n, failure),
                key: const Key('numbers.refusal'),
                style: AppTextStyles.small.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            NumbersPreviewed() => _Preview(preview: preview),
          },
          PrimaryButton(
            key: const Key('numbers.add'),
            label: l10n.addNumbersConfirm,
            onPressed: switch (preview) {
              NumbersPreviewed(canAdd: true) => () => unawaited(
                _add(context, sheet),
              ),
              _ => null,
            },
          ),
        ],
      },
    );
  }

  /// « Ajouter » (or « OK » on the keyboard): the sheet closes once the
  /// street took the numbers; otherwise it stays and says why.
  static Future<void> _add(
    BuildContext context,
    AddNumbersNotifier sheet,
  ) async {
    if (await sheet.add() && context.mounted) Navigator.of(context).pop();
  }
}

/// « Numéros », the field, and « Un numéro, une liste ou une plage
/// (21-25). » under it. The keyboard opens with the sheet.
final class _NumbersField extends StatelessWidget {
  const _NumbersField({required this.onChanged, required this.onSubmitted});

  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        // `MergeSemantics`: TalkBack names the field « Numéros ».
        MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 6,
            children: [
              Text(
                l10n.numbersLabel,
                style: AppTextStyles.fieldLabel.copyWith(color: colors.ink),
              ),
              TextField(
                key: const Key('numbers.field'),
                autofocus: true,
                // Numbers, commas and dashes, sometimes « bis »: no
                // spelling help, which would « correct » 12bis.
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
                onChanged: onChanged,
                onSubmitted: (_) => onSubmitted(),
                decoration: InputDecoration(
                  hintText: l10n.numbersPlaceholder,
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
        Text(
          l10n.numbersHelper,
          style: AppTextStyles.helper.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

/// « APERÇU · 6 NUMÉROS », the numbers, then those already in the street
/// and those coming back from the Corbeille.
final class _Preview extends StatelessWidget {
  const _Preview({required this.preview});

  final NumbersPreviewed preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final note = AppTextStyles.small.copyWith(color: colors.muted);
    final alreadyThere = preview.alreadyThere;
    final fromCorbeille = preview.fromCorbeille;
    return Container(
      key: const Key('numbers.preview'),
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
            l10n.numbersPreviewTitle(preview.numbers.length),
            padding: EdgeInsets.zero,
          ),
          Text(
            shortNumberList(preview.numbers),
            style: AppTextStyles.previewLine.copyWith(color: colors.ink),
          ),
          if (alreadyThere.isNotEmpty)
            Text(
              l10n.numbersAlreadyThere(shortNumberList(alreadyThere)),
              key: const Key('numbers.alreadyThere'),
              style: note,
            ),
          if (fromCorbeille.isNotEmpty)
            Text(
              l10n.numbersFromCorbeille(
                fromCorbeille.length,
                shortNumberList(fromCorbeille),
              ),
              key: const Key('numbers.fromCorbeille'),
              style: note,
            ),
        ],
      ),
    );
  }
}

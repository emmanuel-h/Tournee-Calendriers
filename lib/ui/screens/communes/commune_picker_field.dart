import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/commune_picker/commune_picker_notifier.dart';
import 'package:tournee_calendriers/presentation/import_streets/import_state.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/import_streets/import_messages.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « + Ajouter une commune… » (Create mockup, Équipe): a field that
/// searches geo.api.gouv.fr as the user types, with the communes found
/// under it. Tapping one hands it to [onPick] and empties the field.
final class CommunePickerField extends ConsumerStatefulWidget {
  const CommunePickerField({
    super.key,
    required this.onPick,
    this.autofocus = false,
  });

  final ValueChanged<CommuneOption> onPick;

  /// The keyboard opens at once (the sheet of Équipe).
  final bool autofocus;

  @override
  ConsumerState<CommunePickerField> createState() => _CommunePickerFieldState();
}

final class _CommunePickerFieldState extends ConsumerState<CommunePickerField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pick(CommuneOption commune) {
    _controller.clear();
    ref.read(communePickerProvider.notifier).clear();
    widget.onPick(commune);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final state = ref.watch(communePickerProvider);
    final notifier = ref.read(communePickerProvider.notifier);
    final message = switch (state.suggestions) {
      NoSuggestions() => null,
      CommuneSearchFailed(:final failure) => communeSearchFailureMessage(
        l10n,
        failure,
      ),
      CommunesFound(:final communes) when communes.isEmpty =>
        l10n.communeNoneFound,
      CommunesFound() => null,
    };
    final found = switch (state.suggestions) {
      CommunesFound(:final communes) => communes,
      NoSuggestions() || CommuneSearchFailed() => const <CommuneOption>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        TextField(
          key: const Key('communes.field'),
          controller: _controller,
          autofocus: widget.autofocus,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.bodyLarge.copyWith(color: colors.ink),
          decoration: InputDecoration(
            hintText: l10n.communeAddHint,
            prefixIcon: Icon(Icons.add, color: colors.muted),
            suffixIcon: state.searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: (text) => unawaited(notifier.type(text)),
        ),
        if (message != null)
          Text(
            message,
            key: const Key('communes.message'),
            style: AppTextStyles.small.copyWith(color: colors.muted),
          ),
        if (found.isNotEmpty)
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.divider),
              borderRadius: BorderRadius.circular(AppSizes.fieldRadius),
            ),
            child: Column(
              children: [
                for (final (index, commune) in found.indexed) ...[
                  if (index > 0) Divider(height: 1, color: colors.divider),
                  InkWell(
                    key: ValueKey(
                      'communes.suggestion.${commune.inseeCode.value}',
                    ),
                    onTap: () => _pick(commune),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AppSizes.optionRowHeight,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.fieldPadding,
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        communeLabel(l10n, commune),
                        style: AppTextStyles.body.copyWith(color: colors.ink),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A commune as a chip, « Villefranche-sur-Saône (69400) ✕ », the ✕ a
/// 48 dp target that [onRemove]s it; no ✕ when [onRemove] is null.
final class CommuneChip extends StatelessWidget {
  const CommuneChip({
    super.key,
    required this.label,
    required this.name,
    this.onRemove,
  });

  final String label;

  /// The commune's name, for « Retirer Gleizé ».
  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final onRemove = this.onRemove;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.pillHeight),
      padding: EdgeInsets.only(left: 14, right: onRemove == null ? 14 : 0),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line, width: AppSizes.borderWidth),
        borderRadius: BorderRadius.circular(AppSizes.pillHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: colors.ink),
            ),
          ),
          if (onRemove != null)
            IconButton(
              key: const Key('communes.chip.remove'),
              tooltip: AppLocalizations.of(context).communeRemove(name),
              onPressed: onRemove,
              icon: Icon(
                Icons.close,
                size: AppSizes.smallIcon,
                color: colors.ink,
              ),
            ),
        ],
      ),
    );
  }
}

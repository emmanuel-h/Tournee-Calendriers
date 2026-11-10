import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/street_card/street_card.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/close_icon_button.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The street card at the bottom of Accueil's map (PLAN §5.14): a street
/// of the secteur tapped on the map, its name and commune, « 31/42 faits »
/// in a grey chip, and « Ouvrir », which opens it. The ✕ at the top right
/// is the screen's ([onClose]).
final class StreetCardSheet extends StatelessWidget {
  const StreetCardSheet({super.key, required this.card, required this.onClose});

  final StreetCardInSector card;

  /// The ✕: closes the card, as a tap elsewhere on the map or the back
  /// gesture does.
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      key: const Key('streetCard'),
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.ink,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.sheetRadius),
      ),
      // A `Stack` lays the ✕ over the top right corner of the card,
      // without pushing the grabber or the name down.
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSizes.cardGap,
              children: [
                Center(
                  child: Container(
                    width: AppSizes.dragHandleWidth,
                    height: AppSizes.dragHandleHeight,
                    decoration: BoxDecoration(
                      color: colors.line,
                      borderRadius: BorderRadius.circular(
                        AppSizes.dragHandleHeight / 2,
                      ),
                    ),
                  ),
                ),
                ..._inSector(context, card),
              ],
            ),
          ),
          Positioned(
            top: AppSizes.sheetCloseTop,
            right: AppSizes.sheetCloseRight,
            child: CloseIconButton(
              key: const Key('streetCard.close'),
              tooltip: AppLocalizations.of(context).streetCardClose,
              onPressed: onClose,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _inSector(BuildContext context, StreetCardInSector street) {
    final l10n = AppLocalizations.of(context);
    return [
      _Title(name: street.name, commune: street.commune),
      _Chips(
        [l10n.streetCardProgress(street.done, street.total)],
        semanticsLabels: [
          l10n.streetCardProgressSemantics(street.done, street.total),
        ],
      ),
      PrimaryButton(
        key: const Key('streetCard.open'),
        label: l10n.streetCardOpen,
        onPressed: () =>
            context.push(AppRoutes.streetOf(street.id), extra: street.name),
      ),
    ];
  }
}

/// « Rue Pierre Morin » over « Villefranche-sur-Saône ».
final class _Title extends StatelessWidget {
  const _Title({required this.name, required this.commune});

  final String name;
  final String commune;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Clear of the card's ✕, at the top right.
    return Padding(
      padding: const EdgeInsets.only(right: AppSizes.sheetCloseClearance),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(
            name,
            key: const Key('streetCard.name'),
            style: AppTextStyles.title.copyWith(color: colors.ink),
          ),
          Text(
            commune,
            style: AppTextStyles.streetCounts.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// The street's facts, each in a grey chip (« 31/42 faits »).
final class _Chips extends StatelessWidget {
  const _Chips(this.texts, {this.semanticsLabels});

  final List<String> texts;

  /// What screen readers hear for each chip, when it differs from its text
  /// (« 31 sur 42 faits » for « 31/42 faits »).
  final List<String>? semanticsLabels;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (index, text) in texts.indexed)
          Container(
            key: ValueKey('streetCard.chip.$index'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colors.ground,
              borderRadius: BorderRadius.circular(AppSizes.chipRadius),
            ),
            child: Text(
              text,
              semanticsLabel: semanticsLabels?[index],
              style: AppTextStyles.pill.copyWith(color: colors.ink),
            ),
          ),
      ],
    );
  }
}

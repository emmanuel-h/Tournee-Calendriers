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

/// The street card at the bottom of the map (PLAN §5.4, Pick mockup), on
/// « Ajouter des rues » and Accueil: the street's name and commune, its
/// facts in grey chips, and one button that depends on what the street is
/// to the secteur (PLAN §5.14): « Ajouter au secteur » for a street to add,
/// « Ouvrir » for a street of the secteur.
///
/// « Ouvrir » and « Saisir une rue à la main » open their screens; « Ajouter
/// au secteur » is the screen's ([onAdd]), as is the ✕ at the top right
/// ([onClose]).
final class StreetCardSheet extends StatelessWidget {
  const StreetCardSheet({
    super.key,
    required this.card,
    this.onAdd,
    required this.onClose,
  });

  final StreetCard card;

  /// « Ajouter au secteur »; only a street to add calls it.
  final VoidCallback? onAdd;

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
                ...switch (card) {
                  StreetCardLoading() => [const _Loading()],
                  StreetCardFailed(:final problem) => _failed(context, problem),
                  final StreetCardToAdd street => _toAdd(context, street),
                  final StreetCardInSector street => _inSector(context, street),
                },
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

  List<Widget> _failed(BuildContext context, LookUpProblem problem) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final (title, hint) = switch (problem) {
      LookUpProblem.noNetwork => (
        l10n.streetCardNoNetwork,
        l10n.streetCardNoNetworkHint,
      ),
      LookUpProblem.noStreetHere => (
        l10n.streetCardNoStreetHere,
        l10n.streetCardNoStreetHereHint,
      ),
      LookUpProblem.serviceError => (
        l10n.streetCardServiceError,
        l10n.streetCardServiceErrorHint,
      ),
    };
    return [
      Padding(
        padding: const EdgeInsets.only(right: AppSizes.sheetCloseClearance),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(
              title,
              key: const Key('streetCard.problem'),
              style: AppTextStyles.streetName.copyWith(color: colors.ink),
            ),
            Text(hint, style: AppTextStyles.body.copyWith(color: colors.muted)),
          ],
        ),
      ),
      SecondaryButton(
        key: const Key('streetCard.manual'),
        compact: true,
        leading: const Icon(Icons.edit_outlined, size: AppSizes.smallIcon),
        label: l10n.addStreetsManual,
        onPressed: () => context.push(AppRoutes.manualStreet),
      ),
    ];
  }

  List<Widget> _toAdd(BuildContext context, StreetCardToAdd street) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final adding = street.adding;
    return [
      _Title(name: street.name, commune: street.commune),
      _Chips([
        l10n.streetCardNumbers(street.numberCount),
        l10n.streetCardNotInSector,
      ]),
      if (street.addFailed)
        Text(
          l10n.streetCardAddFailed,
          key: const Key('streetCard.addFailed'),
          style: AppTextStyles.body.copyWith(color: colors.accent),
        ),
      PrimaryButton(
        key: const Key('streetCard.add'),
        label: adding ? l10n.streetCardAdding : l10n.streetCardAdd,
        onPressed: adding ? null : onAdd,
      ),
      // A link in the mockup; a text button keeps its 48 dp of tap target.
      TextButton(
        key: const Key('streetCard.manualLink'),
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
          textStyle: AppTextStyles.rowCount,
        ),
        onPressed: () => context.push(AppRoutes.manualStreet),
        child: Text(l10n.streetCardManualLink),
      ),
    ];
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

/// The street's facts, each in a grey chip (« 19 numéros », « Pas encore
/// dans la tournée »).
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

/// « Recherche de la rue… » while the BAN is asked.
final class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      key: const Key('streetCard.loading'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        spacing: 12,
        children: [
          const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          Text(
            AppLocalizations.of(context).streetCardLoading,
            style: AppTextStyles.body.copyWith(color: colors.muted),
          ),
        ],
      ),
    );
  }
}

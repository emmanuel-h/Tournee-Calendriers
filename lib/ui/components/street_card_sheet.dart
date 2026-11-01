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
/// facts in grey chips, and two buttons that depend on what the street is
/// to the tournée:
///
/// | Street | Red button | Second button |
/// |---|---|---|
/// | to add | Ajouter et me l'attribuer | Ajouter sans m'attribuer |
/// | libre | Me l'attribuer | Ouvrir |
/// | mine | Ouvrir | Ne plus la faire |
/// | someone else's | La faire aussi | Ouvrir |
///
/// « Ouvrir » and « Saisir une rue à la main » open their screens; the
/// other buttons are the screen's ([onAdd], [onTake], [onRelease]), as is
/// the ✕ at the top right ([onClose]).
final class StreetCardSheet extends StatelessWidget {
  const StreetCardSheet({
    super.key,
    required this.card,
    this.onAdd,
    required this.onTake,
    required this.onRelease,
    required this.onClose,
  });

  final StreetCard card;

  /// « Ajouter et me l'attribuer » (true) or « Ajouter sans m'attribuer »
  /// (false); only a street to add calls it.
  final ValueChanged<bool>? onAdd;

  /// « Me l'attribuer », « La faire aussi ».
  final VoidCallback onTake;

  /// « Ne plus la faire ».
  final VoidCallback onRelease;

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
                  final StreetCardInTournee street => _inTournee(
                    context,
                    street,
                  ),
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
    void add(bool assignToMe) => onAdd?.call(assignToMe);
    return [
      _Title(name: street.name, commune: street.commune),
      _Chips([
        l10n.streetCardNumbers(street.numberCount),
        l10n.streetCardNotInTournee,
      ]),
      if (street.addFailed)
        Text(
          l10n.streetCardAddFailed,
          key: const Key('streetCard.addFailed'),
          style: AppTextStyles.body.copyWith(color: colors.accent),
        ),
      PrimaryButton(
        key: const Key('streetCard.addMine'),
        label: adding ? l10n.streetCardAdding : l10n.streetCardAddMine,
        onPressed: adding ? null : () => add(true),
      ),
      SecondaryButton(
        key: const Key('streetCard.addFree'),
        compact: true,
        label: l10n.streetCardAddFree,
        onPressed: adding ? null : () => add(false),
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

  List<Widget> _inTournee(BuildContext context, StreetCardInTournee street) {
    final l10n = AppLocalizations.of(context);
    void open() =>
        context.push(AppRoutes.streetOf(street.id), extra: street.name);
    final names = _joined(l10n, street.coveredBy);
    final cover = switch (street.coverage) {
      StreetCoverage.free => l10n.streetCardFree,
      StreetCoverage.mine when names == null => l10n.streetCardMine,
      StreetCoverage.mine => l10n.streetCardMineWith(names!),
      StreetCoverage.others when names == null => l10n.streetCardOthersUnknown,
      StreetCoverage.others => l10n.streetCardOthers(names!),
    };
    final (primary, secondary) = switch (street.coverage) {
      StreetCoverage.free => (
        (const Key('streetCard.take'), l10n.streetCardTake, onTake),
        (const Key('streetCard.open'), l10n.streetCardOpen, open),
      ),
      StreetCoverage.mine => (
        (const Key('streetCard.open'), l10n.streetCardOpen, open),
        (const Key('streetCard.release'), l10n.streetCardRelease, onRelease),
      ),
      StreetCoverage.others => (
        (const Key('streetCard.take'), l10n.streetCardTakeToo, onTake),
        (const Key('streetCard.open'), l10n.streetCardOpen, open),
      ),
    };
    return [
      _Title(name: street.name, commune: street.commune),
      _Chips(
        [l10n.streetCardProgress(street.done, street.total), cover],
        semanticsLabels: [
          l10n.streetCardProgressSemantics(street.done, street.total),
          cover,
        ],
      ),
      PrimaryButton(key: primary.$1, label: primary.$2, onPressed: primary.$3),
      SecondaryButton(
        key: secondary.$1,
        compact: true,
        label: secondary.$2,
        onPressed: secondary.$3,
      ),
    ];
  }

  /// « Manu », « Manu et Julie », « Manu, Léa et Julie »; null for none.
  static String? _joined(AppLocalizations l10n, List<String> names) =>
      switch (names) {
        [] => null,
        [final only] => only,
        [...final first, final last] => l10n.namesAnd(first.join(', '), last),
      };
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

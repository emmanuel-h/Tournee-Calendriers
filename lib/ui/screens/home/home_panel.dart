import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/home/home_state.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/round/round_card.dart';
import 'package:tournee_calendriers/ui/screens/start/pending_sync_line.dart';
import 'package:tournee_calendriers/ui/screens/start/street_row.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The « Rues » panel at the bottom of Accueil (PLAN §5.14, RunStart
/// mockup): a handle and the totals (« Rues · 31/50 », over every street
/// of the secteur), then « Commencer une tournée » or the tournée's card
/// (PLAN §5.13), every street of the secteur in one list and a muted « +
/// Ajouter des rues » row after them (used a few times a year, #63), then
/// the pending-sync line. A row opens its street.
///
/// It is as tall as it is told ([height]): Accueil decides, as the handle
/// is dragged ([onDrag], [onDragEnd]) or tapped ([onToggle]). Folded down
/// to its totals, the list leaves until there is room for it again.
final class HomePanel extends StatelessWidget {
  const HomePanel({
    super.key,
    required this.state,
    required this.height,
    required this.expanded,
    required this.onDrag,
    required this.onDragEnd,
    required this.onToggle,
  });

  final HomeState state;
  final double height;

  /// The panel fills the room: a tap on the handle brings it back down.
  final bool expanded;

  /// The finger moved the handle by this many dp (down is positive).
  final ValueChanged<double> onDrag;

  /// The finger left the handle at this speed, in dp per second (down is
  /// positive).
  final ValueChanged<double> onDragEnd;

  final VoidCallback onToggle;

  /// Under this room, the list does not fit: only the handle and the
  /// totals show.
  static const _bodyMinHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _PanelSheet(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The handle and the totals move the panel. A tap there shows the
          // whole list, or brings the map back; screen readers have it as
          // a button.
          Semantics(
            button: true,
            onTapHint: expanded ? l10n.homePanelReduce : l10n.homePanelExpand,
            child: GestureDetector(
              key: const Key('home.panel.handle'),
              // `opaque`: the empty room around the handle answers too.
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
              onVerticalDragEnd: (details) =>
                  onDragEnd(details.primaryVelocity ?? 0),
              child: _Totals(state: state),
            ),
          ),
          Expanded(
            // `LayoutBuilder` tells how much room is left under the totals
            // while the panel is dragged.
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxHeight < _bodyMinHeight
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _StreetList(state: state)),
                        // « ☁ Modifications de 3 rues en attente d'envoi »,
                        // only while some wait to be sent.
                        const PendingSyncLine(),
                        const SizedBox(height: AppSizes.gutter),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The height of the folded panel (its handle and totals) when text is
/// drawn through [textScaler]: [AppSizes.homePanelFolded] at 100 %, taller
/// by as much as the « Rues · 31/50 » line grows with the phone's font
/// size, so it still holds the totals at 200 %.
double homePanelFoldedHeight(TextScaler textScaler) {
  double lineHeight(TextScaler scaler) {
    final painter = TextPainter(
      text: const TextSpan(text: 'M', style: AppTextStyles.listHeader),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  return AppSizes.homePanelFolded +
      lineHeight(textScaler) -
      lineHeight(TextScaler.noScaling);
}

/// Opens the street screen of [street]. The name travels along, so the
/// screen has its title before the street is read.
void _open(BuildContext context, StreetRow street) =>
    context.push(AppRoutes.streetOf(street.id), extra: street.name);

/// The white sheet of the panel: rounded top, a shadow over the map.
final class _PanelSheet extends StatelessWidget {
  const _PanelSheet({required this.child, this.height});

  final Widget child;

  /// Null: as tall as its content.
  final double? height;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: colors.surface,
      elevation: 8,
      shadowColor: colors.ink,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.sheetRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(height: height, child: child),
    );
  }
}

/// The handle and « Rues · 31/50 ».
final class _Totals extends StatelessWidget {
  const _Totals({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return SizedBox(
      height: homePanelFoldedHeight(MediaQuery.textScalerOf(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 12),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
            child: Text(
              l10n.homeStreets(state.done, state.total),
              key: const Key('home.header'),
              semanticsLabel: l10n.homeStreetsSemantics(
                state.done,
                state.total,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.listHeader.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Every street of the secteur, or why there is nothing to list.
final class _StreetList extends StatelessWidget {
  const _StreetList({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    Widget note(String text, Key key) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(color: colors.muted),
      ),
    );
    return ListView(
      key: const Key('home.panel.list'),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
      children: [
        // « Commencer une tournée », or the tournée's card (#63).
        const RoundPanelEntry(),
        if (state.hasNoStreet)
          note(l10n.homeNoStreet, const Key('home.noStreet'))
        else
          for (final street in state.streets)
            StreetRowTile(
              key: ValueKey('home.street.${street.id.value}'),
              row: street,
              onTap: () => _open(context, street),
            ),
        const _AddStreetsRow(),
      ],
    );
  }
}

/// « + Ajouter des rues », a muted row after the streets (Home mockup): it
/// opens « Ajouter des rues ».
final class _AddStreetsRow extends StatelessWidget {
  const _AddStreetsRow();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // `button`: screen readers say it can be pressed, as the red button it
    // replaced.
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('start.import'),
        onTap: () => context.push(AppRoutes.addStreets),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.choiceRowHeight,
          ),
          child: Row(
            spacing: 12,
            children: [
              Icon(Icons.add, size: AppSizes.smallIcon, color: colors.muted),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).addStreetsTitle,
                  style: AppTextStyles.compactButton.copyWith(
                    color: colors.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

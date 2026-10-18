import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/domain/street/street_id.dart';
import 'package:tournee_calendriers/presentation/home/home_state.dart';
import 'package:tournee_calendriers/presentation/street_list/street_list_state.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/start/pending_sync_line.dart';
import 'package:tournee_calendriers/ui/screens/start/street_row.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// The « Mes rues » panel at the bottom of Accueil (PLAN §5.3, Home
/// mockup): a handle and the totals (« Mes rues · 43/62 », « Équipe :
/// 41 % »), then the member's streets, the other streets of the tournée
/// under « Autres rues de la tournée », the pending-sync line and
/// « Ajouter des rues ». A row of « Mes rues » opens its street; a row of
/// the others asks Accueil to show its street card ([onOtherStreetTapped],
/// #93), from which the member may take it.
///
/// It is as tall as it is told ([height]): Accueil decides, as the handle
/// is dragged ([onDrag], [onDragEnd]) or tapped ([onToggle]). Folded down
/// to its totals, the list and the button leave until there is room for
/// them again.
final class HomePanel extends StatelessWidget {
  const HomePanel({
    super.key,
    required this.state,
    required this.height,
    required this.expanded,
    required this.onDrag,
    required this.onDragEnd,
    required this.onToggle,
    required this.onOtherStreetTapped,
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

  /// A row under « Autres rues de la tournée » was tapped.
  final ValueChanged<StreetId> onOtherStreetTapped;

  /// Under this room, the list and the button do not fit: only the handle
  /// and the totals show.
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
                        Expanded(
                          child: _StreetList(
                            state: state,
                            onOtherStreetTapped: onOtherStreetTapped,
                          ),
                        ),
                        // « ☁ Modifications de 3 rues en attente d'envoi »,
                        // only while some wait to be sent.
                        const PendingSyncLine(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.gutter,
                            12,
                            AppSizes.gutter,
                            AppSizes.gutter,
                          ),
                          child: PrimaryButton(
                            key: const Key('start.import'),
                            icon: Icons.add,
                            label: l10n.addStreetsTitle,
                            onPressed: () => context.push(AppRoutes.addStreets),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
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

/// The handle, « Mes rues · 43/62 » (« Rues · 9/38 » for a visiting
/// admin) and « Équipe : 41 % ».
final class _Totals extends StatelessWidget {
  const _Totals({required this.state});

  final HomeState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final (header, spoken) = state.visiting
        ? (
            l10n.homeStreetsVisitor(state.done, state.total),
            l10n.homeStreetsVisitorSemantics(state.done, state.total),
          )
        : (
            l10n.homeMyStreets(state.done, state.total),
            l10n.homeMyStreetsSemantics(state.done, state.total),
          );
    return SizedBox(
      height: AppSizes.homePanelFolded,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              spacing: 12,
              children: [
                Expanded(
                  child: Text(
                    header,
                    key: const Key('home.header'),
                    semanticsLabel: spoken,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.listHeader.copyWith(color: colors.ink),
                  ),
                ),
                Text(
                  l10n.homeTeamProgress(state.teamPercent),
                  key: const Key('home.teamProgress'),
                  style: AppTextStyles.small.copyWith(color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Mes rues », then « Autres rues de la tournée »; or why there is
/// nothing to list.
final class _StreetList extends StatelessWidget {
  const _StreetList({required this.state, required this.onOtherStreetTapped});

  final HomeState state;
  final ValueChanged<StreetId> onOtherStreetTapped;

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
    Widget row(StreetRow street, VoidCallback onTap) => StreetRowTile(
      key: ValueKey('home.street.${street.id.value}'),
      row: street,
      onTap: onTap,
    );
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
      children: [
        if (state.hasNoStreet)
          note(l10n.homeNoStreet, const Key('home.noStreet'))
        else if (!state.loading) ...[
          for (final street in state.mine)
            row(street, () => _open(context, street)),
          if (state.mine.isEmpty)
            note(l10n.homeNoStreetOfMine, const Key('home.noStreetOfMine')),
          if (state.others.isNotEmpty) ...[
            SectionHeader(
              l10n.homeOtherStreets(state.others.length),
              key: const Key('home.others'),
              padding: const EdgeInsets.only(top: 16, bottom: 4),
            ),
            for (final street in state.others)
              row(street, () => onOtherStreetTapped(street.id)),
          ],
        ],
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_notifier.dart';
import 'package:tournee_calendriers/presentation/collecte/collecte_view.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_notifier.dart';
import 'package:tournee_calendriers/presentation/team/sector_street_count.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/join_code_text.dart';
import 'package:tournee_calendriers/ui/components/join_qr_code.dart';
import 'package:tournee_calendriers/ui/components/money_words.dart';
import 'package:tournee_calendriers/ui/components/recent_time_text.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/communes/commune_picker_field.dart';
import 'package:tournee_calendriers/ui/screens/my_sectors/my_sectors_sheet.dart';
import 'package:tournee_calendriers/ui/screens/team/team_messages.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Secteur (PLAN §5.8, §5.14, Team and TeamMember mockups), opened by
/// Accueil's title: where the secteur is prepared. First « Changer de
/// secteur », which opens « Mes secteurs » (#135), then the join code
/// and its QR code to show or share, the requests to answer, the members,
/// « RUES (38) » with « + Ajouter des rues » and the Corbeille, the
/// communes, « COLLECTE 2026 », and leaving or deleting the secteur.
///
/// Every member sees the code and answers requests; « Nouveau code »,
/// « Retirer » and « Supprimer le secteur » are the admins' (PLAN §5.12),
/// member or not; every member may « Quitter », and an admin who only
/// visits the tournée « Retirer de Mes secteurs ». The team is followed
/// live; it opens offline from the phone's copy, where a new code and
/// deleting say they need the network.
///
/// Every member covers every street of the secteur (PLAN §5.14): the rows
/// name nobody's streets. « RUES » is for those who prepare the secteur
/// (an active member, an admin), not for a member still pending.
/// « Quitter » and « Supprimer » stay pinned at the bottom while the rest
/// scrolls.
/// « Démarrer une nouvelle campagne » comes with v1.1.
final class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(teamProvider);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppSizes.titleBarWithSubtitleHeight,
        titleSpacing: 4,
        title: switch (state) {
          TeamShown(:final number, :final centre, :final campaign) => _Title(
            title: l10n.teamTitle('$number'),
            subtitle: l10n.teamSubtitle(centre, '$campaign'),
          ),
          NoTeam() ||
          TeamLoading() ||
          TeamUnavailable() => Text(l10n.screenSector),
        },
      ),
      body: SafeArea(
        child: switch (state) {
          TeamShown() => _Team(state: state),
          // « Changer de secteur » stays while the secteur is read, or when
          // it cannot be: Accueil's title only leads here (#135). First, as
          // in the list, so it does not move once the secteur shows.
          TeamLoading() => const Column(children: [_ChangeSector()]),
          NoTeam() => _Message(l10n.teamNoSector),
          TeamUnavailable() => Column(
            children: [
              const _ChangeSector(),
              Expanded(child: _Message(l10n.teamUnavailable)),
            ],
          ),
        },
      ),
    );
  }
}

/// « Tournée 49 » over « CS Villefranche · campagne 2026 ».
final class _Title extends StatelessWidget {
  const _Title({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    spacing: 2,
    children: [
      Text(title, key: const Key('team.title')),
      Text(
        subtitle,
        key: const Key('team.subtitle'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTextStyles.small.copyWith(color: AppColors.of(context).muted),
      ),
    ],
  );
}

/// Why there is no team to show.
final class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        key: const Key('team.message'),
        textAlign: TextAlign.center,
        style: AppTextStyles.body.copyWith(color: AppColors.of(context).muted),
      ),
    ),
  );
}

/// The code card, the requests, the members, the streets, the communes and
/// the collecte, which scroll, over leaving or deleting, pinned at the
/// bottom of the screen.
final class _Team extends ConsumerWidget {
  const _Team({required this.state});

  final TeamShown state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final notifier = ref.read(teamProvider.notifier);

    /// Runs [command]; tells why when it was not done.
    Future<bool> run(Future<TeamActionFailure?> Function() command) async {
      final failure = await command();
      if (failure == null) return true;
      if (context.mounted) {
        showMessageSnackBar(
          ScaffoldMessenger.of(context),
          message: teamActionMessage(l10n, failure),
        );
      }
      return false;
    }

    // A `Column` of two: the list, `Expanded` so it takes all the height
    // the footer leaves, and the footer, as tall as its buttons. Only the
    // list scrolls, so the buttons never move (PLAN §5.8).
    return Column(
      children: [
        Expanded(
          // A `CustomScrollView` scrolls a list of slivers (scrollable
          // pieces); `SliverList.list` builds its children as they come
          // into sight.
          child: CustomScrollView(
            key: const Key('team.list'),
            slivers: [
              SliverList.list(
                children: [
                  const _ChangeSector(),
                  const SizedBox(height: 12),
                  _CodeCard(
                    state: state,
                    onShare: () => shareJoinCode(
                      l10n,
                      number: state.number,
                      centre: state.centre,
                      code: state.code,
                    ),
                    onNewCode: () => unawaited(run(notifier.regenerateCode)),
                  ),
                  if (state.requests.isNotEmpty) ...[
                    SectionHeader(
                      l10n.teamWaitingHeader(state.requests.length),
                      color: colors.accent,
                    ),
                    for (final request in state.requests)
                      _RequestCard(
                        key: ValueKey('team.request.${request.id.value}'),
                        request: request,
                        onAccept: () =>
                            unawaited(run(() => notifier.accept(request.id))),
                        onRefuse: () =>
                            unawaited(run(() => notifier.refuse(request.id))),
                      ),
                  ],
                  SectionHeader(l10n.teamMembersHeader(state.members.length)),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: colors.divider)),
                    ),
                    child: Column(
                      children: [
                        for (final member in state.members)
                          _MemberTile(
                            key: ValueKey('team.member.${member.id.value}'),
                            member: member,
                            onRemove: () async {
                              final confirmed = await showConfirmDialog(
                                context,
                                name: 'team.confirmRemove',
                                title: l10n.teamRemoveTitle(member.name),
                                body: l10n.teamRemoveBody(member.name),
                                confirmLabel: l10n.teamRemove,
                                destructive: true,
                              );
                              if (confirmed) {
                                await run(() => notifier.remove(member.id));
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  if (state.canPrepare) const _Streets(),
                  _Communes(state: state, run: run),
                  const _CollecteSection(),
                  const SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
        Container(
          key: const Key('team.footer'),
          padding: const EdgeInsets.fromLTRB(
            AppSizes.gutter,
            12,
            AppSizes.gutter,
            20,
          ),
          decoration: BoxDecoration(
            color: colors.ground,
            border: Border(top: BorderSide(color: colors.divider)),
          ),
          child: _BottomActions(state: state, run: run),
        ),
      ],
    );
  }
}

/// At the bottom: « Quitter le secteur » for a member (« Retirer de Mes
/// tournées » for an admin who only visits it), and beside it « Supprimer
/// la tournée » for an admin (Team and TeamMember mockups). Each one then
/// goes back to the start screen with no tournée open.
final class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.state, required this.run});

  final TeamShown state;

  /// Runs a command of Secteur; true once done.
  final Future<bool> Function(Future<TeamActionFailure?> Function()) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(teamProvider.notifier);
    final first = state.iAmIn
        ? SecondaryButton(
            key: const Key('team.leave'),
            label: l10n.teamLeave,
            compact: true,
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                name: 'team.confirmLeave',
                title: l10n.teamLeaveTitle('${state.number}'),
                body: l10n.teamLeaveBody,
                confirmLabel: l10n.teamLeaveConfirm,
                destructive: true,
              );
              if (!confirmed) return;
              if (await run(notifier.leave) && context.mounted) {
                context.go(AppRoutes.home);
              }
            },
          )
        // Writes nothing (they were never in the team): no confirmation.
        : SecondaryButton(
            key: const Key('team.forgetVisit'),
            label: l10n.teamForgetVisit,
            compact: true,
            onPressed: () async {
              await notifier.forgetVisit();
              if (context.mounted) context.go(AppRoutes.home);
            },
          );
    if (!state.iAmAdmin) return first;
    return Row(
      spacing: 10,
      children: [
        Expanded(child: first),
        Expanded(
          child: SecondaryButton(
            key: const Key('team.delete'),
            label: l10n.teamDelete,
            compact: true,
            destructive: true,
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                name: 'team.confirmDelete',
                title: l10n.teamDeleteTitle('${state.number}'),
                body: l10n.teamDeleteBody,
                confirmLabel: l10n.teamDeleteConfirm,
                destructive: true,
              );
              if (!confirmed) return;
              if (await run(notifier.deleteSector) && context.mounted) {
                context.go(AppRoutes.home);
              }
            },
          ),
        ),
      ],
    );
  }
}

/// The QR code beside « Code K7P-2QX » and its copy button, « Partager »
/// and, for an admin, « Nouveau code ».
final class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.state,
    required this.onShare,
    required this.onNewCode,
  });

  final TeamShown state;
  final VoidCallback onShare;
  final VoidCallback onNewCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.gutter),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.divider),
        borderRadius: BorderRadius.circular(AppSizes.codeCardRadius),
      ),
      child: Row(
        spacing: 16,
        children: [
          JoinQrCode(
            key: const Key('team.qr'),
            data: state.qrData,
            code: state.code,
            size: AppSizes.qrCode,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  l10n.teamCodeLabel,
                  style: AppTextStyles.small.copyWith(color: colors.muted),
                ),
                JoinCodeText(
                  code: state.code,
                  style: AppTextStyles.joinCode,
                  codeKey: const Key('team.code'),
                  copyKey: const Key('team.copy'),
                ),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PillButton(
                      key: const Key('team.share'),
                      label: l10n.teamShare,
                      onPressed: onShare,
                    ),
                    if (state.iAmAdmin)
                      TextButton(
                        key: const Key('team.newCode'),
                        onPressed: onNewCode,
                        style: TextButton.styleFrom(
                          foregroundColor: colors.accent,
                          textStyle: AppTextStyles.pill.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(l10n.teamNewCode),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A request: « Julie · a demandé à rejoindre · il y a 2 min », then
/// « Accepter » and « Refuser ».
final class _RequestCard extends StatelessWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onRefuse,
  });

  final RequestRow request;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSizes.gutter, 0, AppSizes.gutter, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(
          color: colors.nobodyHome,
          width: AppSizes.borderWidth,
        ),
        borderRadius: BorderRadius.circular(AppSizes.requestCardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 12,
            children: [
              _Avatar(
                name: request.name,
                background: colors.nobodyHome,
                foreground: colors.onNobodyHome,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.teamRequestAsked(
                        recentTimeText(l10n, request.asked),
                      ),
                      style: AppTextStyles.small.copyWith(color: colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: l10n.teamAcceptSemantics(request.name),
                  excludeSemantics: true,
                  child: FilledButton(
                    key: const Key('team.request.accept'),
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.done,
                      foregroundColor: colors.onDone,
                      minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                      textStyle: AppTextStyles.compactButton,
                    ),
                    child: Text(l10n.teamAccept),
                  ),
                ),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: l10n.teamRefuseSemantics(request.name),
                  excludeSemantics: true,
                  child: OutlinedButton(
                    key: const Key('team.request.refuse'),
                    onPressed: onRefuse,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
                      textStyle: AppTextStyles.compactButton,
                    ),
                    child: Text(l10n.teamRefuse),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A member: « Manu (vous) · admin », and for an admin a ⋮ on the others
/// that offers « Retirer ». The member on the phone has the dark avatar.
final class _MemberTile extends StatelessWidget {
  const _MemberTile({super.key, required this.member, required this.onRemove});

  final MemberRow member;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final named = member.isMe ? l10n.teamMemberYou(member.name) : member.name;
    final label = member.isAdmin ? l10n.teamMemberAdmin(named) : named;
    return Container(
      constraints: const BoxConstraints(minHeight: AppSizes.memberRowHeight),
      padding: EdgeInsets.fromLTRB(16, 0, member.canRemove ? 4 : 16, 0),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        spacing: 12,
        children: [
          member.isMe
              ? _Avatar(
                  name: member.name,
                  background: colors.ink,
                  foreground: colors.surface,
                )
              : _Avatar(
                  name: member.name,
                  background: colors.divider,
                  foreground: colors.ink,
                ),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodyLarge.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (member.canRemove)
            // A menu of one item, as the mockup's ⋮: removing someone is
            // never one tap away.
            // `onSelected` runs once the menu has closed, so the dialog it
            // opens is not closed with the menu.
            PopupMenuButton<_MemberAction>(
              key: const Key('team.member.options'),
              tooltip: l10n.teamMemberOptions(member.name),
              icon: Icon(Icons.more_vert, color: colors.ink),
              onSelected: (action) => switch (action) {
                _MemberAction.remove => onRemove(),
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: const Key('team.member.remove'),
                  value: _MemberAction.remove,
                  child: Text(l10n.teamRemove),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// « RUES (38) » (PLAN §5.14, Team mockup): « + Ajouter des rues », which
/// opens « Ajouter des rues » (§5.4; its ✕ comes back here), then the
/// Corbeille (§5.11). The count is the streets Accueil lists, read from the
/// phone, so it shows offline; « RUES » alone until they are read.
final class _Streets extends ConsumerWidget {
  const _Streets();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // `.value`: the count once read, null before.
    final count = ref.watch(sectorStreetCountProvider).value;
    final corbeille = ref.watch(corbeilleProvider.select((s) => s.count));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          count == null
              ? l10n.teamStreetsHeaderCounting
              : l10n.teamStreetsHeader(count),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.divider)),
          ),
          child: Column(
            children: [
              _LinkTile(
                key: const Key('team.addStreets'),
                icon: Icons.add,
                title: l10n.addStreetsTitle,
                subtitle: l10n.teamAddStreetsHint,
                // `push`: « Ajouter des rues » stacks on Secteur, so its ✕
                // and the back gesture come back here.
                onTap: () => context.push(AppRoutes.addStreets),
              ),
              _LinkTile(
                key: const Key('team.corbeille'),
                icon: Icons.delete_outline,
                title: l10n.teamCorbeille(corbeille),
                onTap: () => context.push(AppRoutes.trash),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// « ⇄ Changer de secteur › », the first row of Secteur (#135): opens
/// « Mes secteurs », over Secteur, which then shows the secteur picked.
final class _ChangeSector extends StatelessWidget {
  const _ChangeSector();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.of(context).divider)),
    ),
    child: _LinkTile(
      key: const Key('team.changeSector'),
      icon: Icons.swap_horiz,
      title: AppLocalizations.of(context).teamChangeSector,
      onTap: () => showMySectorsSheet(context),
    ),
  );
}

/// A row that opens another screen: an icon in a round ground-coloured
/// badge, a bold title (and a muted line under it), then ›.
final class _LinkTile extends StatelessWidget {
  const _LinkTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final subtitle = this.subtitle;
    return Semantics(
      // A node of its own: the rows around it are not buttons.
      container: true,
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.memberRowHeight,
            ),
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              spacing: 12,
              children: [
                Container(
                  width: AppSizes.avatar,
                  height: AppSizes.avatar,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.ground,
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.avatarIcon,
                    color: colors.ink,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: colors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: AppTextStyles.small.copyWith(
                            color: colors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: AppSizes.smallIcon,
                  color: colors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// « COLLECTE 2026 » and its row, « 600 € récoltés » over « 41 dons en 4
/// tournées », which opens « Collecte 2026 » (PLAN §5.13, RunTeam
/// mockup). The secteur's money only: never a member's, by decision.
/// Nothing shows until the tournées are read, or when they cannot be.
final class _CollecteSection extends ConsumerWidget {
  const _CollecteSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(collecteProvider);
    if (view is! CollecteShown) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final title = l10n.collecteTitle('${view.campaign}');
    final raised = l10n.teamCollecteRaised(eurosText(l10n, view.totals.cents));
    final dons = l10n.teamCollecteDons(
      l10n.donCount(view.totals.count),
      view.rounds.length,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        Semantics(
          container: true,
          button: true,
          label: l10n.teamCollecteSpoken(title, raised, dons),
          excludeSemantics: true,
          child: Material(
            color: colors.surface,
            child: InkWell(
              key: const Key('team.collecte'),
              onTap: () => context.push(AppRoutes.collecte),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.memberRowHeight,
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                decoration: BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: colors.divider),
                  ),
                ),
                child: Row(
                  spacing: 12,
                  children: [
                    Container(
                      width: AppSizes.avatar,
                      height: AppSizes.avatar,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.ground,
                      ),
                      child: Text(
                        l10n.amountSuffix,
                        style: AppTextStyles.avatarInitial.copyWith(
                          color: colors.ink,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 2,
                        children: [
                          Text(
                            raised,
                            key: const Key('team.collecte.raised'),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: colors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            dons,
                            key: const Key('team.collecte.dons'),
                            style: AppTextStyles.small.copyWith(
                              color: colors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: AppSizes.smallIcon,
                      color: colors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The member's initial in a circle; decoration only, the name is beside
/// it.
final class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.background,
    required this.foreground,
  });

  final String name;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: AppSizes.avatar,
      height: AppSizes.avatar,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: background),
      child: Text(
        // `characters` walks what a reader sees as one letter: « É » typed
        // as E and an accent, or an emoji, stays whole.
        name.characters.first.toUpperCase(),
        style: AppTextStyles.avatarInitial.copyWith(color: foreground),
      ),
    ),
  );
}

/// « Communes (2) »: the secteur's communes, each with ✕ but the last
/// one, then « + Ajouter une commune », which opens a sheet that searches
/// geo.api.gouv.fr (#78). A secteur created before the communes shows
/// only the button. Only those who prepare the secteur change them.
final class _Communes extends ConsumerWidget {
  const _Communes({required this.state, required this.run});

  final TeamShown state;

  /// Runs a command of Secteur; true once done.
  final Future<bool> Function(Future<TeamActionFailure?> Function()) run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final notifier = ref.read(teamProvider.notifier);
    if (state.communes.isEmpty && !state.canPrepare) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l10n.teamCommunesHeader(state.communes.length)),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.divider)),
          ),
          child: Column(
            children: [
              for (final commune in state.communes)
                Container(
                  key: ValueKey('team.commune.${commune.inseeCode.value}'),
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.memberRowHeight,
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    commune.removable ? 4 : 16,
                    0,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(bottom: BorderSide(color: colors.divider)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          commune.name,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                      if (commune.removable)
                        IconButton(
                          key: const Key('team.commune.remove'),
                          tooltip: l10n.communeRemove(commune.name),
                          icon: Icon(Icons.close, color: colors.ink),
                          onPressed: () => unawaited(
                            run(
                              () => notifier.removeCommune(commune.inseeCode),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (state.canPrepare)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.gutter,
              12,
              AppSizes.gutter,
              0,
            ),
            child: SecondaryButton(
              key: const Key('team.addCommune'),
              leading: const Icon(Icons.add),
              label: l10n.teamAddCommune,
              compact: true,
              onPressed: () => _addCommune(context, notifier),
            ),
          ),
      ],
    );
  }

  /// Opens the sheet that searches a commune; the one picked is added and
  /// the sheet closes.
  Future<void> _addCommune(BuildContext context, TeamNotifier notifier) =>
      showAppBottomSheet<void>(
        context: context,
        builder: (sheet) => SheetScaffold(
          title: AppLocalizations.of(sheet).teamAddCommune,
          children: [
            CommunePickerField(
              autofocus: true,
              onPick: (commune) {
                Navigator.of(sheet).pop();
                unawaited(run(() => notifier.addCommune(commune)));
              },
            ),
          ],
        ),
      );
}

/// What the ⋮ of a member offers.
enum _MemberAction { remove }

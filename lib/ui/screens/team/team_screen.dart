import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tournee_calendriers/presentation/corbeille/corbeille_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_notifier.dart';
import 'package:tournee_calendriers/presentation/team/team_state.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/confirm_dialog.dart';
import 'package:tournee_calendriers/ui/components/recent_time_text.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Équipe (👥, PLAN §5.8, Team mockup): the join code and its QR code to
/// show or share, the requests to answer, the members, the Corbeille, and
/// leaving or deleting the tournée.
///
/// Every member sees the code and answers requests; « Nouveau code »,
/// « Retirer » and « Supprimer la tournée » are the creator's, who cannot
/// leave. The team is followed live; it opens offline from the phone's
/// copy, where a new code and deleting say they need the network.
///
/// The members' street counts (« 5 rues ») come with the streets taken by
/// each member (M3), and « Démarrer une nouvelle campagne » with v1.1.
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
          TeamUnavailable() => Text(l10n.screenTeam),
        },
      ),
      body: SafeArea(
        child: switch (state) {
          TeamShown() => _Team(state: state),
          TeamLoading() => const SizedBox.shrink(),
          NoTeam() => _Message(l10n.teamNoTournee),
          TeamUnavailable() => _Message(l10n.teamUnavailable),
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

/// The code card, the requests, the members, the Corbeille, then leaving
/// or deleting at the bottom of the screen (or after the rest, when the
/// team is long).
final class _Team extends ConsumerWidget {
  const _Team({required this.state});

  final TeamShown state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final notifier = ref.read(teamProvider.notifier);
    final corbeille = ref.watch(corbeilleProvider.select((s) => s.count));

    /// Runs [command]; tells why when it was not done.
    Future<bool> run(Future<TeamActionFailure?> Function() command) async {
      final failure = await command();
      if (failure == null) return true;
      if (context.mounted) {
        showMessageSnackBar(
          ScaffoldMessenger.of(context),
          message: switch (failure) {
            TeamActionFailure.teamChanged => l10n.teamChanged,
            TeamActionFailure.offline => l10n.teamOffline,
          },
        );
      }
      return false;
    }

    // A `CustomScrollView` scrolls a list of slivers (scrollable pieces):
    // here the content, then `SliverFillRemaining`, which takes the room
    // left under it, so the buttons sit at the bottom of the screen yet
    // scroll after a long team.
    return CustomScrollView(
      slivers: [
        SliverList.list(
          children: [
            _CodeCard(
              state: state,
              onShare: () => unawaited(
                SharePlus.instance.share(
                  ShareParams(
                    text: l10n.teamShareText(
                      '${state.number}',
                      state.centre,
                      state.code,
                    ),
                  ),
                ),
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
                  _CorbeilleTile(
                    count: corbeille,
                    onTap: () => context.push(AppRoutes.trash),
                  ),
                ],
              ),
            ),
          ],
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.gutter,
                24,
                AppSizes.gutter,
                20,
              ),
              child: state.iAmCreator
                  ? SecondaryButton(
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
                        if (await run(notifier.deleteTournee) &&
                            context.mounted) {
                          context.go(AppRoutes.home);
                        }
                      },
                    )
                  // The creator cannot leave (PLAN §6.1): they delete.
                  : SecondaryButton(
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
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The QR code beside « Code K7P-2QX », « Partager » and, for the
/// creator, « Nouveau code ».
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
    // A QR code scans best dark on light: it keeps the light palette's ink
    // and white in the dark theme too.
    const qrInk = AppColors.light;
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
          Semantics(
            // A node of its own, not merged with the code beside it.
            container: true,
            label: l10n.teamQrSemantics(state.code),
            image: true,
            excludeSemantics: true,
            child: ColoredBox(
              color: qrInk.surface,
              child: QrImageView(
                key: const Key('team.qr'),
                data: state.qrData,
                size: AppSizes.qrCode,
                padding: const EdgeInsets.all(4),
                eyeStyle: QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: qrInk.ink,
                ),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: qrInk.ink,
                ),
              ),
            ),
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
                Text(
                  state.code,
                  key: const Key('team.code'),
                  style: AppTextStyles.joinCode.copyWith(color: colors.ink),
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
                    if (state.iAmCreator)
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

/// A member: « Manu (vous) · créateur », and for the creator a ⋮ on the
/// others that offers « Retirer ».
final class _MemberTile extends StatelessWidget {
  const _MemberTile({super.key, required this.member, required this.onRemove});

  final MemberRow member;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final named = member.isMe ? l10n.teamMemberYou(member.name) : member.name;
    final label = member.isCreator ? l10n.teamMemberCreator(named) : named;
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
          member.isCreator
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

/// « Corbeille · 2 éléments › », which opens the Corbeille (PLAN §5.11).
final class _CorbeilleTile extends StatelessWidget {
  const _CorbeilleTile({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final label = l10n.teamCorbeille(count);
    return Semantics(
      // A node of its own: the member rows above it are not buttons.
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        child: InkWell(
          key: const Key('team.corbeille'),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.memberRowHeight,
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
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
                    Icons.delete_outline,
                    size: AppSizes.avatarIcon,
                    color: colors.ink,
                  ),
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

/// What the ⋮ of a member offers.
enum _MemberAction { remove }

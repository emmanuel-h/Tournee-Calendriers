import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/screens/settings/changelog.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// « Nouveautés » (Paramètres → Version, PLAN §5.9, Changelog mockup): each
/// version, newest first, with its day and what it brings. Text shipped
/// with the app, so it works offline.
final class ChangelogScreen extends ConsumerWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final releases = ref.watch(changelogProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.changelogTitle)),
      body: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.divider)),
          ),
          child: ListView(
            children: [
              for (final release in releases) _ReleaseSection(release),
            ],
          ),
        ),
      ),
    );
  }
}

/// « 1.0.0  16 oct. 2026 » then its lines, on white with a line under it.
final class _ReleaseSection extends StatelessWidget {
  const _ReleaseSection(this.release);

  final Release release;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          // One text with two styles, so the small date sits on the same
          // baseline as the big number; read as « 1.0.0 · 16 oct. 2026 ».
          // `container`: its own node, so a screen reader stops on it
          // rather than reading the whole version in one go.
          Semantics(
            container: true,
            header: true,
            label: l10n.changelogHeading(release.version, release.date),
            excludeSemantics: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: release.version,
                    style: AppTextStyles.listHeader,
                  ),
                  const WidgetSpan(child: SizedBox(width: 10)),
                  TextSpan(
                    text: l10n.changelogDate(release.date),
                    style: AppTextStyles.small.copyWith(color: colors.muted),
                  ),
                ],
              ),
              style: TextStyle(color: colors.ink),
            ),
          ),
          for (final note in release.notes(l10n)) _Note(note),
        ],
      ),
    );
  }
}

/// « • Première version. »: the bullet is only drawn, screen readers hear
/// the line alone.
final class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.body.copyWith(
      color: AppColors.of(context).ink,
      height: 1.4,
    );
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 20, child: Text('•', style: style)),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}

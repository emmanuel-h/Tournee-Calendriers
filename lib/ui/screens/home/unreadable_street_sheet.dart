import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tournee_calendriers/presentation/admin/admin_notifier.dart';
import 'package:tournee_calendriers/presentation/home/home_notifier.dart';
import 'package:tournee_calendriers/presentation/home/street_row.dart';
import 'package:tournee_calendriers/ui/components/app_buttons.dart';
import 'package:tournee_calendriers/ui/components/sheet_scaffold.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Opens the sheet of the unreadable street [row].
Future<void> showUnreadableStreetSheet(
  BuildContext context,
  UnreadableStreetRow row,
) => showAppBottomSheet<void>(
  context: context,
  builder: (_) => UnreadableStreetSheet(row: row),
);

/// The sheet of a street whose data cannot be read (PLAN §5.16,
/// StreetUnreadableSheet mockup): its name (« Rue illisible » when that
/// cannot be read either), why it shows so, and what can be done. An admin
/// also gets « Supprimer la rue », which deletes it for the whole team and
/// closes the sheet; nobody else sees it (the security rules would refuse
/// it anyway).
final class UnreadableStreetSheet extends ConsumerWidget {
  const UnreadableStreetSheet({super.key, required this.row});

  final UnreadableStreetRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    // `watch`: should the admin status arrive while the sheet shows, the
    // button appears.
    final isAdmin = ref.watch(adminProvider);
    final text = AppTextStyles.body.copyWith(color: colors.ink, height: 1.4);
    return SheetScaffold(
      key: const Key('unreadable.sheet'),
      title: row.name ?? l10n.unreadableStreetNoName,
      spacing: 10,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            // ⚠ drawn as an icon: the text glyph shows as a yellow emoji
            // on Android. The words say it all.
            ExcludeSemantics(
              child: Icon(
                Icons.warning_amber_rounded,
                size: AppSizes.alertGlyph,
                color: colors.accent,
              ),
            ),
            Expanded(child: Text(l10n.unreadableStreetBody, style: text)),
          ],
        ),
        Text(
          l10n.unreadableStreetAdminHint,
          style: AppTextStyles.small.copyWith(color: colors.muted),
        ),
        if (isAdmin) ...[
          const SizedBox(height: 10),
          SecondaryButton(
            key: const Key('unreadable.delete'),
            label: l10n.deleteStreetAction,
            compact: true,
            destructive: true,
            onPressed: () {
              unawaited(
                ref.read(homeProvider.notifier).deleteUnreadable(row.id),
              );
              Navigator.of(context).pop();
            },
          ),
          Text(
            l10n.unreadableStreetAdminsOnly,
            textAlign: TextAlign.center,
            style: AppTextStyles.helper.copyWith(color: colors.muted),
          ),
        ],
      ],
    );
  }
}

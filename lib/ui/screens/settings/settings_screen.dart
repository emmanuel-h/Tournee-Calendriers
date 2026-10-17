import 'package:flutter/material.dart';
// `appBuildName`: the app's version from `pubspec.yaml`, put into the app
// by the Flutter build itself, so no package is needed to read it.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tournee_calendriers/presentation/account/device_id_state.dart';
import 'package:tournee_calendriers/presentation/my_tournees/my_tournees_notifier.dart';
import 'package:tournee_calendriers/presentation/settings/settings_notifier.dart';
import 'package:tournee_calendriers/ui/components/copy_button.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/router/app_routes.dart';
import 'package:tournee_calendriers/ui/screens/my_tournees/my_tournees_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/name_sheet.dart';
import 'package:tournee_calendriers/ui/screens/settings/theme_sheet.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Paramètres (⚙, PLAN §5.9, Settings mockup): the member's first name and
/// « Mes tournées », then the theme, the privacy page, the version (a tap
/// opens « Nouveautés »), the licences, the phone's uid (« Identifiant de
/// l'appareil », PLAN §5.12) and the data credits. Works offline; the
/// screen signs the phone in when it opens, so the uid shows once online.
///
/// The « Hors-ligne » section of the mockup comes with the download of a
/// tournée (M4).
final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final settings = ref.watch(settingsProvider);
    final tournee = ref.watch(currentTourneeProvider);
    // Watching it signs the phone in (`accountProvider`).
    final deviceId = ref.watch(deviceIdProvider);
    // Null only for a build without a version in `pubspec.yaml`.
    const version = appBuildName ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.screenSettings)),
      body: SafeArea(
        child: ListView(
          children: [
            SectionHeader(
              l10n.settingsYou,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            ),
            _RowGroup(
              children: [
                _SettingRow(
                  key: const Key('settings.name'),
                  label: l10n.settingsName,
                  value: settings.name,
                  onTap: () => showNameSheet(context),
                ),
                _SettingRow(
                  key: const Key('settings.myTournees'),
                  label: l10n.myTourneesTitle,
                  value: tournee == null
                      ? null
                      : l10n.settingsMyTourneesValue(
                          '${tournee.number.value}',
                          '${tournee.campaign.value}',
                        ),
                  onTap: () => showMyTourneesSheet(context),
                ),
              ],
            ),
            SectionHeader(l10n.settingsApplication),
            _RowGroup(
              children: [
                _SettingRow(
                  key: const Key('settings.theme'),
                  label: l10n.settingsTheme,
                  value: themeName(l10n, settings.theme),
                  onTap: () => showThemeSheet(context),
                ),
                _SettingRow(
                  key: const Key('settings.privacy'),
                  label: l10n.settingsPrivacy,
                  onTap: () => context.push(AppRoutes.privacy),
                ),
                _SettingRow(
                  key: const Key('settings.version'),
                  label: l10n.settingsVersion,
                  value: version,
                  semanticsLabel: l10n.settingsVersionSemantics(version),
                  onTap: () => context.push(AppRoutes.changelog),
                ),
                _SettingRow(
                  key: const Key('settings.licences'),
                  label: l10n.settingsLicences,
                  // Flutter's own page lists every licence registered: the
                  // packages' and the bundled fonts' (`font_licenses.dart`).
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: l10n.appTitle,
                    applicationVersion: version,
                  ),
                ),
                _DeviceIdRow(deviceId: deviceId),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Text(
                l10n.settingsCredits,
                key: const Key('settings.credits'),
                style: AppTextStyles.helper.copyWith(
                  color: colors.muted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Identifiant de l'appareil » over the whole uid (selectable, in
/// monospace so `l` and `1` differ), « Administrateur » under it on an
/// admin's phone, and its copy button; « Pas encore de compte… » offline
/// before any account. Not a button itself: the copy button is.
final class _DeviceIdRow extends StatelessWidget {
  const _DeviceIdRow({required this.deviceId});

  final DeviceIdState deviceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final muted = AppTextStyles.small.copyWith(color: colors.muted);
    return Container(
      key: const Key('settings.deviceId'),
      constraints: const BoxConstraints(minHeight: AppSizes.settingRowHeight),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        spacing: 12,
        children: [
          Expanded(
            // One node for screen readers: the label and its value.
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    l10n.deviceIdLabel,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  ...switch (deviceId) {
                    DeviceIdShown(:final id, :final isAdmin) => [
                      // A long press selects it, for whoever prefers that
                      // to the copy button.
                      SelectableText(
                        id,
                        key: const Key('settings.deviceIdValue'),
                        style: AppTextStyles.identifier.copyWith(
                          color: colors.ink,
                        ),
                      ),
                      if (isAdmin) Text(l10n.deviceIdIsAdmin, style: muted),
                    ],
                    DeviceIdSigningIn() => [
                      Text(l10n.accountSigningIn, style: muted),
                    ],
                    DeviceIdOffline() => [
                      Text(l10n.deviceIdNoAccount, style: muted),
                    ],
                  },
                ],
              ),
            ),
          ),
          if (deviceId case DeviceIdShown(:final id))
            DeviceIdCopyButton(key: const Key('settings.copyDeviceId'), id: id),
        ],
      ),
    );
  }
}

/// Rows on white with a line above the first and under each one.
final class _RowGroup extends StatelessWidget {
  const _RowGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.of(context).divider)),
    ),
    child: Column(children: children),
  );
}

/// « Prénom    Manu › »: what the row sets, its value, and a chevron.
final class _SettingRow extends StatelessWidget {
  const _SettingRow({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.semanticsLabel,
  });

  final String label;

  /// Shown at the right, before the chevron; none when null.
  final String? value;

  /// What screen readers hear instead of « label, value ».
  final String? semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final value = this.value ?? '';
    return Semantics(
      button: true,
      label:
          semanticsLabel ??
          (value.isEmpty ? label : l10n.settingsRowSemantics(label, value)),
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppSizes.settingRowHeight,
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              spacing: 12,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Takes the room left, so the value and the chevron sit at
                // the right edge, value or not.
                Expanded(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: colors.muted,
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

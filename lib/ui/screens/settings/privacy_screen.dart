import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tournee_calendriers/ui/components/action_snack_bar.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_sizes.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

/// The public privacy policy: `PRIVACY.md` at the root of the repository,
/// the same text as this page (#36).
final privacyPolicyUrl = Uri.parse(
  'https://github.com/emmanuel-h/Tournee-Calendriers/blob/main/PRIVACY.md',
);

/// Confidentialité (Paramètres, PLAN §5.9): what the app keeps and where,
/// as PLAN §8.3 states it, then « Politique complète en ligne ↗ ». The text
/// works offline; only the link needs the network.
final class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final sections = [
      (l10n.privacyAccountTitle, l10n.privacyAccountBody),
      (l10n.privacyDataTitle, l10n.privacyDataBody),
      (l10n.privacyLocationTitle, l10n.privacyLocationBody),
      (l10n.privacyHostingTitle, l10n.privacyHostingBody),
      (l10n.privacyDeletionTitle, l10n.privacyDeletionBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacy)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final (title, body) in sections) ...[
              SectionHeader(title),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  body,
                  style: AppTextStyles.body.copyWith(
                    color: colors.ink,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Divider(height: 1, thickness: 1, color: colors.divider),
            const _OnlinePolicyRow(),
          ],
        ),
      ),
    );
  }
}

/// « Politique complète en ligne ↗ »: opens [privacyPolicyUrl] in the
/// phone's browser, or says where to find it when no browser opens.
final class _OnlinePolicyRow extends StatelessWidget {
  const _OnlinePolicyRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return Semantics(
      button: true,
      label: l10n.privacyOnlineSemantics,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('privacy.online'),
        onTap: () => _open(context),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSizes.settingRowHeight,
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            spacing: 12,
            children: [
              Expanded(
                child: Text(
                  l10n.privacyOnline,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // The ↗ of the mockup: the page opens outside the app.
              Icon(
                Icons.open_in_new,
                size: AppSizes.smallIcon,
                color: colors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `externalApplication`: the phone's browser, not a view inside the app,
  /// so the page keeps its own back button and address bar. `launchUrl`
  /// answers false when nothing can open the address, and may throw a
  /// `PlatformException` when the plugin fails: both end in the snackbar.
  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    bool opened;
    try {
      opened = await launchUrl(
        privacyPolicyUrl,
        mode: LaunchMode.externalApplication,
      );
    } on PlatformException {
      opened = false;
    }
    if (opened) return;
    showMessageSnackBar(
      messenger,
      message: l10n.privacyOnlineFailed('$privacyPolicyUrl'),
    );
  }
}

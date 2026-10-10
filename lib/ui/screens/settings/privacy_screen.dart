import 'package:flutter/material.dart';
import 'package:tournee_calendriers/ui/components/section_header.dart';
import 'package:tournee_calendriers/ui/l10n/app_localizations.dart';
import 'package:tournee_calendriers/ui/theme/app_colors.dart';
import 'package:tournee_calendriers/ui/theme/app_typography.dart';

/// Confidentialité (Paramètres, PLAN §5.9): what the app keeps and where,
/// as PLAN §8.3 states it. Text only, offline.
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
          ],
        ),
      ),
    );
  }
}

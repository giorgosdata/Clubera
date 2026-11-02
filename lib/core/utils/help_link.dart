// Link to the «How it works» page on the Clubera website: detailed
// instructions for everyone (fans, players, Club Admins).

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const kAdminGuideUrl = 'https://clubera-global.com/#/how';

Future<void> openAdminGuide(BuildContext context) async {
  final ok = await launchUrl(Uri.parse(kAdminGuideUrl), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Οι οδηγίες είναι στο $kAdminGuideUrl')),
    );
  }
}

/// «Οδηγίες» button for app bars.
class AdminGuideButton extends StatelessWidget {
  const AdminGuideButton({super.key});

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: () => openAdminGuide(context),
        icon: const Icon(Icons.help_outline, color: AppTheme.accent, size: 20),
        label: const Text('Οδηγίες', style: TextStyle(color: AppTheme.accent)),
      );
}

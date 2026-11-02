// Link to the detailed guide for Club Admins on the Clubera website.
// The page must exist at exactly this address on www.clubera-global.com.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

const kAdminGuideUrl = 'https://www.clubera-global.com/odigos';

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

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'auth_token.dart';
import 'l10n/app_l10n.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.agraz.app';

/// Checks Play Store for an update and asks the user before installing.
/// Returns true if the user chose Update (session is cleared so the new
/// build does not keep a stale login).
/// Works only for installs from Play (prod / internal testing). Safe no-op elsewhere.
Future<bool> promptInAppUpdateIfNeeded(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return false;

  try {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return false;
    }
    if (!context.mounted) return false;

    final update = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Update available')),
        content: Text(
          tr(
            'A new version of AgRaz is available. Update now without opening Play Store? You will be logged out so new features work after login.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Later')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Update')),
          ),
        ],
      ),
    );

    if (update != true || !context.mounted) return false;

    // Stale JWT / cached session would hide new APIs after the update.
    await clearAuthToken();

    if (info.immediateUpdateAllowed) {
      final result = await InAppUpdate.performImmediateUpdate();
      if (result == AppUpdateResult.inAppUpdateFailed && context.mounted) {
        await _openPlayStore(context);
      }
      return true;
    }

    if (info.flexibleUpdateAllowed) {
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        await InAppUpdate.completeFlexibleUpdate();
      } else if (result == AppUpdateResult.inAppUpdateFailed &&
          context.mounted) {
        await _openPlayStore(context);
      }
      return true;
    }

    if (!context.mounted) return false;
    await _openPlayStore(context);
    return true;
  } catch (e) {
    debugPrint('In-app update check skipped: $e');
    return false;
  }
}

Future<void> _openPlayStore(BuildContext context) async {
  final uri = Uri.parse(_playStoreUrl);
  final market = Uri.parse('market://details?id=com.agraz.app');
  try {
    if (await canLaunchUrl(market)) {
      await launchUrl(market, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Could not open Play Store')),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }
}

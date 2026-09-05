import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../app/app.dart' show rootNavigatorKey;
import 'notification_service.dart';

/// Google Play In-App Updates (Flexible Update) handling.
///
/// Google Play is the source of truth for update availability: an update check
/// runs automatically at startup (never blocking the UI). If an update exists
/// the user is offered [Update] / [Skip]; choosing [Update] starts a Flexible
/// Update so the app stays usable while it downloads, followed by a
/// "Restart to install" prompt.
///
/// Everything here is best-effort: if Google Play is missing or the network
/// fails the check simply reports "no update" and MediaRescue keeps working.
class UpdateService {
  UpdateService._();

  static bool _checkInProgress = false;

  /// Version code the user skipped during the current session (in-memory only,
  /// so future updates on later launches can still be announced).
  static int? _skippedVersionCode;

  static StreamSubscription<InstallStatus>? _installListener;

  /// Checks Google Play for a newer version. Runs in the background.
  static Future<void> startUpdateCheck() async {
    if (_checkInProgress) return;
    _checkInProgress = true;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (info.availableVersionCode == _skippedVersionCode) return;
      // If the user just arrived via an FCM announcement there is no need to
      // also pop the dialog up for the same release.
      if (NotificationService.launchedFromUpdateNotification) return;
      await _showUpdateDialog(info);
    } catch (_) {
      // No Google Play / offline / update check failure: treat as no update.
    } finally {
      _checkInProgress = false;
    }
  }

  /// Attempts to run a Flexible Update for the provided info. Called from the
  /// dialog's [Update] button.
  static Future<void> startFlexibleUpdate(AppUpdateInfo info) async {
    try {
      // Watch download progress so we can offer "Restart to install".
      _installListener?.cancel();
      _installListener = InAppUpdate.installUpdateListener.listen((status) {
        if (status == InstallStatus.downloaded) {
          _showRestartToInstallDialog();
        } else if (status == InstallStatus.canceled ||
            status == InstallStatus.failed) {
          _installListener?.cancel();
          _restartPromptPending = false;
        }
      });

      final result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        // The future completes once the download has finished.
        _showRestartToInstallDialog();
      }
      // userDeniedUpdate / failures are handled silently — the user can keep
      // using the current version.
      if (result != AppUpdateResult.success) {
        _installListener?.cancel();
        _restartPromptPending = false;
      }
    } catch (_) {
      _installListener?.cancel();
      _restartPromptPending = false;
    }
  }

  /// Guards against showing the "Restart to install" dialog twice (the stream
  /// and the returned future can both report `downloaded`).
  static bool _restartPromptPending = false;

  static Future<void> _showRestartToInstallDialog() async {
    if (_restartPromptPending) return;
    _restartPromptPending = true;

    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) {
      _restartPromptPending = false;
      return;
    }
    await showDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('MediaRescue update downloaded'),
        content: const Text(
          'The update has finished downloading. Restart now to install it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              _installListener?.cancel();
              _restartPromptPending = false;
              // Handed over to Google Play, which performs the installation.
              try {
                await InAppUpdate.completeFlexibleUpdate();
              } catch (_) {
                // Play could not start the install; keep using the app.
              }
            },
            child: const Text('Restart to install'),
          ),
        ],
      ),
    );
    _restartPromptPending = false;
  }

  static Future<void> _showUpdateDialog(AppUpdateInfo info) async {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;

    // Returns 'update', 'skip' or null (Android back button). A dismissal that
    // is not an explicit "Update" counts as skip for the running session only.
    final decision = await showDialog<String>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('MediaRescue update available'),
        content: const Text('A new version of MediaRescue is available.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('skip'),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('update'),
            child: const Text('Update'),
          ),
        ],
      ),
    );

    if (decision == 'update') {
      await startFlexibleUpdate(info);
    } else {
      // Skipped (or dismissed with the back button): remember this version for
      // the rest of the session so the same update is not advertised again.
      _skippedVersionCode = info.availableVersionCode;
    }
  }
}
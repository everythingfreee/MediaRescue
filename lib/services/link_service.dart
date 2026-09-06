import 'package:url_launcher/url_launcher.dart';

/// Centralized helpers for opening external links (Google Play, GitHub,
/// the official Privacy Policy and mailto:) using the platform's installed
/// applications. All methods return `false` instead of throwing when the
/// target app / link is unavailable, so the UI can handle failures gracefully.
class LinkService {
  LinkService._();

  /// Official MediaRescue Play Store page.
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?'
      'id=com.shaheer.mediarescue.mediarescue';

  /// Official MediaRescue GitHub repository.
  static const String githubUrl = 'https://github.com/everythingfreee/MediaRescue';

  /// Official GitHub Issues page.
  static const String githubIssuesUrl =
      'https://github.com/everythingfreee/MediaRescue/issues';

  /// Official Shizuku Play Store page (used only by the optional
  /// Advanced Scanning setup guide).
  static const String shizukuPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=moe.shizuku.privileged.api';

  /// Official Shizuku GitHub releases page.
  static const String shizukuGitHubUrl =
      'https://github.com/RikkaApps/Shizuku/releases';

  /// Official (canonical) hosted Privacy Policy.
  static const String privacyPolicyUrl =
      'https://everythingfreee.github.io/Apps-Privacy-Policy/'
      'Apps-Privacy-Policy/mediarescue.html';

  /// Official contact email address.
  static const String contactEmail = 'mediarescue@sanaullahshaheer.dpdns.org';

  /// Opens the MediaRescue page in the Google Play Store application when
  /// available, falling back to the Play Store website in the browser.
  static Future<bool> openPlayStore() async {
    // market:// prefers the installed Play Store app.
    final marketUri =
        Uri.parse('market://details?id=com.shaheer.mediarescue.mediarescue');
    try {
      if (await canLaunchUrl(marketUri)) {
        final opened =
            await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        if (opened) return true;
      }
    } catch (_) {
      // Fall through to the web URL.
    }
    return openUrl(playStoreUrl);
  }

  /// Opens the official Shizuku page in the Google Play Store application
  /// when available, falling back to the Play Store website in the browser.
  /// Used only by the optional Advanced Scanning setup guide.
  static Future<bool> openShizukuPlayStore() async {
    final marketUri =
        Uri.parse('market://details?id=moe.shizuku.privileged.api');
    try {
      if (await canLaunchUrl(marketUri)) {
        final opened =
            await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        if (opened) return true;
      }
    } catch (_) {
      // Fall through to the web URL.
    }
    return openUrl(shizukuPlayStoreUrl);
  }

  /// Opens an http(s) URL in the default browser.
  static Future<bool> openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Ignore; report as failed.
    }
    return false;
  }

  /// Opens the user's installed email application with a message addressed to
  /// [contactEmail]. Returns `false` when no email client is available.
  static Future<bool> openEmailCompose() async {
    final uri = Uri(
      scheme: 'mailto',
      path: contactEmail,
      queryParameters: const {'subject': 'MediaRescue Support'},
    );
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Ignore; report as failed.
    }
    return false;
  }
}
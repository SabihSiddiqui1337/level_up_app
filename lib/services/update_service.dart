import 'package:package_info_plus/package_info_plus.dart' as package_info_plus;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class UpdateService {
  // Optional override for latest version; when unset, no update prompt is shown
  static const String _latestVersionKey = 'latest_version_override';

  // Store URLs – replace with your real store links
  // Note: If these are placeholder URLs, update checks will be disabled
  static const String androidStoreUrl =
      'https://play.google.com/store/apps/details?id=com.levelupsports.app';
  static const String iosStoreUrl =
      'https://apps.apple.com/app/id0000000000'; // Placeholder - replace with real App Store ID

  // Return app version from platform (e.g., 1.0.0)
  static Future<String> getCurrentVersion() async {
    final info = await package_info_plus.PackageInfo.fromPlatform();
    return info.version;
  }

  // Return build number from platform (e.g., 8)
  static Future<String> getBuildNumber() async {
    final info = await package_info_plus.PackageInfo.fromPlatform();
    return info.buildNumber;
  }

  // Get latest version override from local storage (set during a release)
  static Future<String?> getLatestVersionOverride() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_latestVersionKey);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  // Set/clear latest version override
  static Future<void> setLatestVersionOverride(String? version) async {
    final prefs = await SharedPreferences.getInstance();
    if (version == null || version.trim().isEmpty) {
      await prefs.remove(_latestVersionKey);
    } else {
      await prefs.setString(_latestVersionKey, version.trim());
    }
  }

  static Future<bool> isUpdateAvailable() async {
    // First check if store URL is valid (not a placeholder)
    final storeUri = getStoreUri();
    if (storeUri == null) {
      // No valid store URL means app isn't published yet, so no updates available
      return false;
    }
    
    final latest = await getLatestVersionOverride();
    if (latest == null) return false; // no configured update
    
    final current = await getCurrentVersion();
    final needsUpdate = _isVersionLower(current, latest);
    
    // If current version is equal to or higher than latest, clear the override
    if (!needsUpdate) {
      await setLatestVersionOverride(null);
      return false;
    }
    
    return true;
  }

  // Compare semantic versions like 1.0.0 vs 1.0.1
  static bool _isVersionLower(String a, String b) {
    List<int> pa = _parse(a);
    List<int> pb = _parse(b);
    for (int i = 0; i < 3; i++) {
      if (pa[i] < pb[i]) return true;
      if (pa[i] > pb[i]) return false;
    }
    return false; // equal or higher
  }

  static List<int> _parse(String v) {
    // Strip build suffix if present (e.g., 1.0.0+8)
    final core = v.split('+').first;
    final parts = core.split('.');
    int major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    int minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    int patch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return [major, minor, patch];
  }

  // Provide the correct store URI for the current platform, or null if placeholder
  static Uri? getStoreUri() {
    final raw = Platform.isIOS ? iosStoreUrl : androidStoreUrl;
    // Heuristics: treat placeholder links as invalid
    if (raw.contains('id0000000000')) return null;
    if (raw.contains('example.com')) return null;
    return Uri.tryParse(raw);
  }
}

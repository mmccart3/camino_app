import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' show supportsLaunchMode;
import 'package:url_launcher/url_launcher_string.dart';

class SafeLinks {
  static String? emailAddress(String? value) {
    final address = value?.trim();
    if (address == null ||
        !RegExp(
          r'^[a-zA-Z0-9._+%-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
        ).hasMatch(address)) {
      return null;
    }
    return address;
  }

  static String emailUrl(String value) {
    final address = emailAddress(value);
    if (address == null) throw ArgumentError('Invalid email address.');
    return 'mailto:${Uri.encodeComponent(address)}';
  }

  static Future<void> email(String value) async {
    final url = emailUrl(value);
    try {
      if (await launchUrlString(url, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      throw StateError(
        'Could not open an email app. You can email ${emailAddress(value)} manually.',
      );
    }
    throw StateError(
      'No email app is available. You can email ${emailAddress(value)} manually.',
    );
  }

  static Future<void> call(String internationalNumber) async {
    if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(internationalNumber)) {
      throw ArgumentError('Invalid phone number.');
    }
    try {
      if (await launchUrlString(
        'tel:$internationalNumber',
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {
      throw StateError(
        'Could not open a calling app. You can dial $internationalNumber manually.',
      );
    }
    throw StateError(
      'No calling app is available. You can dial $internationalNumber manually.',
    );
  }

  static bool isWebsite(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !RegExp(r'[\x00-\x20\x7f]').hasMatch(value);
  }

  static Future<void> openWebsite(String value) async {
    if (!isWebsite(value)) throw ArgumentError('Invalid website link.');
    if (!await launchUrlString(value, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open this website.');
    }
  }

  static bool isSafe(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !RegExp(r'[\x00-\x20\x7f]').hasMatch(value);
  }

  static bool isBookingWebsite(String value) {
    if (!isSafe(value)) return false;
    final host = Uri.parse(value).host.toLowerCase();
    return host == 'booking.com' || host.endsWith('.booking.com');
  }

  static Future<void> openBookingWebsite(String value) async {
    if (!isBookingWebsite(value)) {
      throw ArgumentError('Invalid Booking.com website link.');
    }
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    var mode = LaunchMode.externalApplication;
    if (mobile) {
      // Android Custom Tabs can follow verified app links into Booking.com.
      // The embedded Android WebView keeps web navigation in this activity.
      mode = defaultTargetPlatform == TargetPlatform.android
          ? LaunchMode.inAppWebView
          : LaunchMode.inAppBrowserView;
      if (!await supportsLaunchMode(mode)) {
        // Never fall back to an external application for mobile bookings.
        throw StateError(
          'An embedded booking browser is unavailable on this device.',
        );
      }
    }
    // Keep affiliate parameters and their original encoding unchanged.
    if (!await launchUrlString(
      value,
      mode: mode,
      browserConfiguration: const BrowserConfiguration(showTitle: true),
      webViewConfiguration: const WebViewConfiguration(
        enableJavaScript: true,
        enableDomStorage: true,
      ),
    )) {
      throw StateError('Could not open the booking website. Please try again.');
    }
  }

  static Future<void> open(String value) async {
    if (!isSafe(value)) {
      throw ArgumentError('Only valid HTTPS links can be opened.');
    }
    if (isBookingWebsite(value)) return openBookingWebsite(value);
    // Pass the original database string: never rebuild query parameters.
    if (!await launchUrlString(value, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open this link.');
    }
  }
}

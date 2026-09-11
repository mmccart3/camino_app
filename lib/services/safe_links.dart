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

  static Future<void> open(String value) async {
    if (!isSafe(value)) {
      throw ArgumentError('Only valid HTTPS links can be opened.');
    }
    // Pass the original database string: never rebuild query parameters.
    if (!await launchUrlString(value, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open this link.');
    }
  }
}

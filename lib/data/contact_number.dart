/// Validated dial target. Source values remain unchanged in the record.
class ContactNumber {
  final String international;
  const ContactNumber._(this.international);
  String get whatsAppUrl => 'https://wa.me/${international.substring(1)}';

  static String? _clean(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (!RegExp(r'^\+?[0-9 ()-]+$').hasMatch(raw)) return null;
    return raw.replaceAll(RegExp(r'[ ()-]'), '');
  }

  /// WhatsApp numbers must be stored in full international format.
  static ContactNumber? internationalNumber(Object? value) {
    var digits = _clean(value);
    if (digits == null) return null;
    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }
    if (!RegExp(r'^[1-9][0-9]{6,14}$').hasMatch(digits)) return null;
    return ContactNumber._('+$digits');
  }

  static ContactNumber? phone(Object? number, Object? countryCode) {
    final digits = _clean(number);
    if (digits == null || !RegExp(r'[1-9]').hasMatch(digits)) return null;
    if (digits.startsWith('+') || digits.startsWith('00')) {
      return internationalNumber(digits);
    }
    var code = _clean(countryCode);
    if (code == null) return null;
    if (code.startsWith('+')) code = code.substring(1);
    if (code.startsWith('00')) code = code.substring(2);
    if (!RegExp(r'^[1-9][0-9]{0,2}$').hasMatch(code)) return null;
    return internationalNumber('$code$digits');
  }
}

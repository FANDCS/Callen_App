










final RegExp _nonDigits = RegExp(r'[^0-9]');

String normalizedPhoneKey(String raw) {
  final digitsOnly = raw.replaceAll(_nonDigits, '');
  if (digitsOnly.length <= 9) return digitsOnly;
  return digitsOnly.substring(digitsOnly.length - 9);
}

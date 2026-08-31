










String normalizedPhoneKey(String raw) {
  final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length <= 9) return digitsOnly;
  return digitsOnly.substring(digitsOnly.length - 9);
}

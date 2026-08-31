import 'dart:typed_data';

class PhoneEntry {
  final String number;
  final String label;
  const PhoneEntry({required this.number, required this.label});
}

class ContactEntry {
  final String id;
  final String displayName;
  final List<PhoneEntry> phoneNumbers;
  final Uint8List? photoThumbnail;

  const ContactEntry({
    required this.id,
    required this.displayName,
    required this.phoneNumbers,
    this.photoThumbnail,
  });
}

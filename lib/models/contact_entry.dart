import 'dart:typed_data';

class ContactEntry {
  final String id;
  final String displayName;
  final List<String> phoneNumbers;
  // Thumbnail bytes απευθείας από το device contacts store (μικρή,
  // γρήγορη εικόνα — όχι το full-res). Δεν συγχρονίζεται (βάρος),
  // ξαναδιαβάζεται κάθε φορά τοπικά από τη συσκευή.
  final Uint8List? photoThumbnail;

  const ContactEntry({
    required this.id,
    required this.displayName,
    required this.phoneNumbers,
    this.photoThumbnail,
  });
}

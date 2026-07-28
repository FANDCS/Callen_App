import '../models/contact_entry.dart';

/// Interface πρόσβασης στις επαφές της συσκευής.
abstract class ContactsService {
  Future<bool> requestPermission();

  /// Αν το [sourceIds] είναι null ή κενό, επιστρέφει επαφές από όλες
  /// τις πηγές (accounts) της συσκευής (προεπιλογή). Αν δοθούν
  /// συγκεκριμένα IDs, φέρνει επαφές μόνο από αυτές τις πηγές,
  /// αφαιρώντας διπλότυπα (ίδιος αριθμός τηλεφώνου).
  Future<List<ContactEntry>> getContacts({List<String>? sourceIds});

  /// Λίστα διαθέσιμων πηγών επαφών στη συσκευή (π.χ. λογαριασμός
  /// Google, Samsung account, τοπική συσκευή) — id + εμφανιζόμενο
  /// όνομα, για να τα δείξει το Settings screen ως επιλογές.
  Future<List<ContactSource>> getAvailableSources();

  /// Ανοίγει την προεπιλεγμένη εφαρμογή Επαφών της συσκευής,
  /// δείχνοντας τη συγκεκριμένη επαφή (native "view contact" ecran).
  Future<void> openExternalContact(String contactId);
}

class ContactSource {
  final String id; // "$type|$name", μοναδικό αναγνωριστικό
  final String displayName;
  const ContactSource({required this.id, required this.displayName});
}

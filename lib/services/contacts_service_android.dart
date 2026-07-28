import 'package:flutter_contacts/flutter_contacts.dart' as native;

import '../models/contact_entry.dart';
import '../utils/phone_utils.dart';
import 'contacts_service.dart';

// Χρησιμοποιούμε το v2 API του flutter_contacts (2.x), όχι το
// permission_handler — το πακέτο έχει πλέον δικό του permissions API.
class ContactsServiceAndroid implements ContactsService {
  @override
  Future<bool> requestPermission() async {
    final status = await native.FlutterContacts.permissions
        .request(native.PermissionType.read);
    return status == native.PermissionStatus.granted;
  }

  @override
  Future<List<ContactSource>> getAvailableSources() async {
    final accounts = await native.FlutterContacts.accounts.getAll();
    return accounts
        .map((a) => ContactSource(
              id: '${a.type}|${a.name}',
              displayName: a.name,
            ))
        .toList();
  }

  @override
  Future<List<ContactEntry>> getContacts({List<String>? sourceIds}) async {
    const properties = {
      native.ContactProperty.name,
      native.ContactProperty.phone,
      native.ContactProperty.photoThumbnail,
    };

    List<native.Contact> rawContacts;

    if (sourceIds == null || sourceIds.isEmpty) {
      // Καμία επιλεγμένη πηγή -> όλες οι επαφές, όπως πριν.
      rawContacts = await native.FlutterContacts.getAll(properties: properties);
    } else {
      // Φέρνουμε ξεχωριστά ανά επιλεγμένη πηγή (account) και τα
      // ενώνουμε, αφαιρώντας διπλότυπα βάσει αριθμού τηλεφώνου.
      final accounts = await native.FlutterContacts.accounts.getAll();
      final selectedAccounts = accounts
          .where((a) => sourceIds.contains('${a.type}|${a.name}'))
          .toList();

      rawContacts = [];
      for (final account in selectedAccounts) {
        final fromThisAccount = await native.FlutterContacts.getAll(
          properties: properties,
          account: account,
        );
        rawContacts.addAll(fromThisAccount);
      }
    }

    final entries = rawContacts
        .map((c) => ContactEntry(
              id: c.id ?? '',
              displayName: (c.displayName?.isNotEmpty ?? false)
                  ? c.displayName!
                  : 'Άγνωστο όνομα',
              phoneNumbers: c.phones.map((p) => p.number).toList(),
              photoThumbnail: c.photo?.thumbnail,
            ))
        .where((c) => c.phoneNumbers.isNotEmpty)
        .toList();

    // Αφαίρεση διπλότυπων: ίδιος κανονικοποιημένος αριθμός τηλεφώνου
    // (π.χ. η ίδια επαφή αποθηκευμένη και στο Google και στο Samsung
    // account) -> κρατάμε μόνο την πρώτη εμφάνιση.
    final seenNumbers = <String>{};
    final deduped = <ContactEntry>[];
    for (final entry in entries) {
      final key = normalizedPhoneKey(entry.phoneNumbers.first);
      if (seenNumbers.add(key)) {
        deduped.add(entry);
      }
    }
    return deduped;
  }

  @override
  Future<void> openExternalContact(String contactId) async {
    // Ανοίγει το native Contacts app της συσκευής στη συγκεκριμένη
    // επαφή — δεν εμφανίζει τίποτα μέσα στη δική μας εφαρμογή, απλά
    // κάνει redirect έξω. (v2 API: FlutterContacts.native.showViewer,
    // όχι το παλιό openExternalView της v1.)
    await native.FlutterContacts.native.showViewer(contactId);
  }
}

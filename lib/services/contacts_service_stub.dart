import '../models/contact_entry.dart';
import 'contacts_service.dart';

class ContactsServiceStub implements ContactsService {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<List<ContactEntry>> getContacts({List<String>? sourceIds}) async => [];

  @override
  Future<List<ContactSource>> getAvailableSources() async => [];

  @override
  Future<void> openExternalContact(String contactId) async {
    throw UnsupportedError(
      'Το άνοιγμα εξωτερικής εφαρμογής επαφών υποστηρίζεται μόνο σε Android.',
    );
  }
}

import '../models/contact_entry.dart';
import '../utils/app_strings.dart';
import 'contacts_service.dart';

const _fallbackStrings = AppStrings(AppLanguage.greek);

class ContactsServiceStub implements ContactsService {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<List<ContactEntry>> getContacts({
    List<String>? sourceIds,
    AppStrings? strings,
  }) async =>
      [];

  @override
  Future<List<ContactSource>> getAvailableSources({AppStrings? strings}) async =>
      [];

  @override
  Future<void> openExternalContact(String contactId, {AppStrings? strings}) async {
    final s = strings ?? _fallbackStrings;
    throw UnsupportedError(s.openExternalContactUnsupported);
  }
}

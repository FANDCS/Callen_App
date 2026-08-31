import '../models/contact_entry.dart';
import '../utils/app_strings.dart';

const deviceSourceId = 'device';
const simSourceId = 'sim';

abstract class ContactsService {
  Future<bool> requestPermission();

  // `strings` is optional so existing call sites keep compiling, but pass it
  // whenever available so returned names/labels are localized correctly
  // instead of falling back to Greek.
  Future<List<ContactEntry>> getContacts({
    List<String>? sourceIds,
    AppStrings? strings,
  });

  Future<List<ContactSource>> getAvailableSources({AppStrings? strings});

  Future<void> openExternalContact(String contactId, {AppStrings? strings});
}

class ContactSource {
  final String id; 
  final String displayName;
  const ContactSource({required this.id, required this.displayName});
}

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as native;

import '../models/contact_entry.dart';
import '../utils/phone_utils.dart';
import 'contacts_service.dart';

const _simChannel = MethodChannel('gr.fandcs.callen/sim');
const simSourceId = 'sim';

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
    final sources = accounts
        .map((a) => ContactSource(
              id: '${a.type}|${a.name}',
              displayName: a.name,
            ))
        .toList();
    sources.add(const ContactSource(id: simSourceId, displayName: 'SIM κάρτα'));
    return sources;
  }

  Future<List<ContactEntry>> _getSimContacts() async {
    final result = await _simChannel.invokeMethod('getSimContacts');
    if (result == null) return [];
    final list = List<Map<Object?, Object?>>.from(result as List);
    return list
        .map((m) {
          final name = (m['name'] as String?) ?? '';
          final number = (m['number'] as String?) ?? '';
          return ContactEntry(
            id: 'sim-$number',
            displayName: name.isNotEmpty ? name : number,
            phoneNumbers: [number],
          );
        })
        .where((c) => c.phoneNumbers.first.isNotEmpty)
        .toList();
  }

  @override
  Future<List<ContactEntry>> getContacts({List<String>? sourceIds}) async {
    const properties = {
      native.ContactProperty.name,
      native.ContactProperty.phone,
      native.ContactProperty.photoThumbnail,
    };

    final entries = <ContactEntry>[];

    if (sourceIds == null || sourceIds.isEmpty) {
      final rawContacts =
          await native.FlutterContacts.getAll(properties: properties);
      entries.addAll(_mapContacts(rawContacts));
      entries.addAll(await _getSimContacts());
    } else {
      final wantsSim = sourceIds.contains(simSourceId);
      final accountSourceIds =
          sourceIds.where((id) => id != simSourceId).toList();

      if (accountSourceIds.isNotEmpty) {
        final accounts = await native.FlutterContacts.accounts.getAll();
        final selectedAccounts = accounts
            .where((a) => accountSourceIds.contains('${a.type}|${a.name}'))
            .toList();
        for (final account in selectedAccounts) {
          final fromThisAccount = await native.FlutterContacts.getAll(
            properties: properties,
            account: account,
          );
          entries.addAll(_mapContacts(fromThisAccount));
        }
      }

      if (wantsSim) {
        entries.addAll(await _getSimContacts());
      }
    }

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

  List<ContactEntry> _mapContacts(List<native.Contact> raw) {
    return raw
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
  }

  @override
  Future<void> openExternalContact(String contactId) async {
    await native.FlutterContacts.native.showViewer(contactId);
  }
}

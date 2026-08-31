import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as native;

import '../models/contact_entry.dart';
import '../utils/app_strings.dart';
import '../utils/phone_utils.dart';
import 'contacts_service.dart';

const _simChannel = MethodChannel('gr.fandcs.callen/sim');

// Fallback used only when a caller doesn't pass `strings` (kept for
// backwards compatibility with call sites that haven't been updated yet).
const _fallbackStrings = AppStrings(AppLanguage.greek);

class ContactsServiceAndroid implements ContactsService {
  @override
  Future<bool> requestPermission() async {
    final status = await native.FlutterContacts.permissions
        .request(native.PermissionType.read);
    return status == native.PermissionStatus.granted;
  }

  @override
  Future<List<ContactSource>> getAvailableSources({AppStrings? strings}) async {
    final s = strings ?? _fallbackStrings;
    return [
      ContactSource(id: deviceSourceId, displayName: s.contactSourceDevice),
      ContactSource(id: simSourceId, displayName: s.contactSourceSim),
    ];
  }

  Future<List<ContactEntry>> _getDeviceContacts(AppStrings s) async {
    const properties = {
      native.ContactProperty.name,
      native.ContactProperty.phone,
      native.ContactProperty.photoThumbnail,
    };
    final raw = await native.FlutterContacts.getAll(properties: properties);
    return raw
        .map((c) => ContactEntry(
              id: c.id ?? '',
              displayName: (c.displayName?.isNotEmpty ?? false)
                  ? c.displayName!
                  : s.unknownContactName,
              phoneNumbers: c.phones
                  .map((p) => PhoneEntry(number: p.number, label: _labelFor(p, s)))
                  .toList(),
              photoThumbnail: c.photo?.thumbnail,
            ))
        .where((c) => c.phoneNumbers.isNotEmpty)
        .toList();
  }

  Future<List<ContactEntry>> _getSimContacts() async {
    try {
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
              phoneNumbers: [PhoneEntry(number: number, label: 'SIM')],
            );
          })
          .where((c) => c.phoneNumbers.first.number.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<ContactEntry>> getContacts({
    List<String>? sourceIds,
    AppStrings? strings,
  }) async {
    final s = strings ?? _fallbackStrings;
    final entries = <ContactEntry>[];
    final wantDevice = sourceIds == null || sourceIds.isEmpty || sourceIds.contains(deviceSourceId);
    final wantSim = sourceIds == null || sourceIds.isEmpty || sourceIds.contains(simSourceId);

    if (wantDevice) {
      entries.addAll(await _getDeviceContacts(s));
    }
    if (wantSim) {
      entries.addAll(await _getSimContacts());
    }

    final seenNumbers = <String>{};
    final deduped = <ContactEntry>[];
    for (final entry in entries) {
      final key = normalizedPhoneKey(entry.phoneNumbers.first.number);
      if (seenNumbers.add(key)) {
        deduped.add(entry);
      }
    }
    return deduped;
  }

  String _labelFor(native.Phone p, AppStrings s) {
    final raw = p.label.toString().toLowerCase();
    if (raw.contains('mobile')) return s.phoneLabelMobile;
    if (raw.contains('home')) return s.phoneLabelHome;
    if (raw.contains('work')) return s.phoneLabelWork;
    if (raw.contains('main')) return s.phoneLabelMain;
    if (raw.contains('pager')) return s.phoneLabelPager;
    return s.phoneLabelOther;
  }

  @override
  Future<void> openExternalContact(String contactId, {AppStrings? strings}) async {
    await native.FlutterContacts.native.showViewer(contactId);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/contact_entry.dart';
import '../services/calls_service.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/greek_text.dart';
import '../utils/phone_country.dart';

class ContactsScreen extends StatefulWidget {
  final ContactsService contactsService;
  final CallsService callsService;
  final AppStrings strings;
  final SettingsStore store;
  const ContactsScreen({
    super.key,
    required this.contactsService,
    required this.callsService,
    required this.strings,
    required this.store,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<ContactEntry> _allContacts = [];
  bool _loading = true;
  bool _permissionGranted = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final granted = await widget.contactsService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() {
        _permissionGranted = false;
        _loading = false;
      });
      return;
    }
    final contacts = await widget.contactsService.getContacts(
      sourceIds: widget.store.contactSources,
      strings: widget.strings,
    );
    contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
    if (!mounted) return;
    setState(() {
      _permissionGranted = true;
      _allContacts = contacts;
      _loading = false;
    });
  }

  List<ContactEntry> _filter(String rawQuery) {
    final query = normalizeForSearch(rawQuery.trim());
    if (query.isEmpty) return _allContacts;
    final digitsQuery = query.replaceAll(RegExp(r'[^0-9]'), '');
    return _allContacts.where((c) {
      final nameMatch = normalizeForSearch(c.displayName).contains(query);
      final phoneMatch = digitsQuery.isNotEmpty &&
          c.phoneNumbers.any(
            (p) => p.number.replaceAll(RegExp(r'[^0-9]'), '').contains(digitsQuery),
          );
      return nameMatch || phoneMatch;
    }).toList();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first.characters.first;
    final last = parts.length > 1 && parts.last.isNotEmpty
        ? parts.last.characters.first
        : '';
    return (first + last).toUpperCase();
  }

  Color _colorFor(String name) {
    const palette = [
      AppColors.brand,
      AppColors.outgoing,
      AppColors.incoming,
      Color(0xFF8E5B3F),
      Color(0xFF5C4D9B),
    ];
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % palette.length;
    return palette[idx];
  }

  // ΑΥΤΗ Η ΜΕΘΟΔΟΣ είναι το picker αριθμού όταν η επαφή έχει
  // περισσότερους από έναν αριθμούς τηλεφώνου. Αν δεν βλέπεις αυτό το
  // σχόλιο μέσα στο αρχείο σου μετά την αντικατάσταση, δεν έχεις
  // εφαρμόσει σωστά αυτό το zip.
  Future<void> _callContact(ContactEntry c) async {
    final s = widget.strings;
    if (c.phoneNumbers.length <= 1) {
      if (c.phoneNumbers.isEmpty) return;
      await widget.callsService.placeCall(c.phoneNumbers.first.number);
      return;
    }
    final chosen = await showModalBottomSheet<PhoneEntry>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  s.chooseNumberTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              ...c.phoneNumbers.map((p) => ListTile(
                    leading: const Icon(Icons.call),
                    title: Text(p.number),
                    subtitle: Text(p.label),
                    onTap: () => Navigator.of(context).pop(p),
                  )),
            ],
          ),
        );
      },
    );
    if (chosen != null) {
      await widget.callsService.placeCall(chosen.number);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              return TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: s.searchContactsHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: value.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _searchController.clear,
                        ),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              return _buildList(_filter(value.text), s);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildList(List<ContactEntry> filtered, AppStrings s) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_permissionGranted) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(s.contactsPermissionNeeded, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );
    }

    if (_allContacts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(s.contactsEmpty, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(s.contactsNoMatch),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        cacheExtent: 800,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final c = filtered[index];
          final color = _colorFor(c.displayName);
          final hasPhoto = c.photoThumbnail != null;
          final flag = c.phoneNumbers.isNotEmpty
              ? flagForPhoneNumber(c.phoneNumbers.first.number)
              : null;

          return RepaintBoundary(
            child: Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () => widget.contactsService
                    .openExternalContact(c.id, strings: widget.strings),
                onLongPress: c.phoneNumbers.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: c.phoneNumbers.first.number),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${s.numberCopied}: ${c.phoneNumbers.first.number}',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.16),
                  backgroundImage:
                      hasPhoto ? MemoryImage(c.photoThumbnail!) : null,
                  child: hasPhoto
                      ? null
                      : Text(
                          _initials(c.displayName),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                ),
                title: Text(
                  c.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Row(
                  children: [
                    if (flag != null) ...[
                      Text(flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        c.phoneNumbers.isEmpty
                            ? ''
                            : c.phoneNumbers.length > 1
                                ? '${c.phoneNumbers.first.number} +${c.phoneNumbers.length - 1}'
                                : c.phoneNumbers.first.number,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton.filledTonal(
                  icon: const Icon(Icons.call),
                  onPressed: () => _callContact(c),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

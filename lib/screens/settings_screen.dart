import 'package:flutter/material.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../utils/app_strings.dart';

/// Ρυθμίσεις εφαρμογής: θέμα εμφάνισης, γλώσσα, πηγή επαφών, και
/// χειροκίνητη ρύθμιση server συγχρονισμού. Το sync engine δεν υπάρχει
/// ακόμα — αυτή η φόρμα απλά αποθηκεύει τοπικά τις τιμές, έτοιμες για
/// όταν φτιαχτεί.
class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final SettingsStore store;
  final AppStrings strings;
  final String languagePref;
  final ValueChanged<String> onLanguageChanged;
  final ContactsService contactsService;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.store,
    required this.strings,
    required this.languagePref,
    required this.onLanguageChanged,
    required this.contactsService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _apiKeyController;
  bool _syncEnabled = false;
  bool _saved = false;
  List<ContactSource> _availableSources = [];
  late Set<String> _selectedSources;
  bool _loadingSources = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.store.syncServerUrl);
    _apiKeyController = TextEditingController(text: widget.store.syncApiKey);
    _syncEnabled = widget.store.syncEnabled;
    _selectedSources = widget.store.contactSources.toSet();
    _loadSources();
  }

  Future<void> _loadSources() async {
    final granted = await widget.contactsService.requestPermission();
    if (!granted) {
      if (!mounted) return;
      setState(() => _loadingSources = false);
      return;
    }
    final sources = await widget.contactsService.getAvailableSources();
    if (!mounted) return;
    setState(() {
      _availableSources = sources;
      _loadingSources = false;
    });
  }

  void _toggleSource(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedSources.add(id);
      } else {
        _selectedSources.remove(id);
      }
    });
    widget.store.setContactSources(_selectedSources.toList());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.store.setSyncServerUrl(_urlController.text.trim());
    await widget.store.setSyncApiKey(_apiKeyController.text.trim());
    await widget.store.setSyncEnabled(_syncEnabled);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.settingsSaved)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.strings.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              widget.strings.settingsAppearance,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: Text(widget.strings.langSystem),
            value: ThemeMode.system,
            groupValue: widget.themeMode,
            onChanged: (m) => m != null ? widget.onThemeModeChanged(m) : null,
          ),
          RadioListTile<ThemeMode>(
            title: Text(widget.strings.themeLight),
            value: ThemeMode.light,
            groupValue: widget.themeMode,
            onChanged: (m) => m != null ? widget.onThemeModeChanged(m) : null,
          ),
          RadioListTile<ThemeMode>(
            title: Text(widget.strings.themeDark),
            value: ThemeMode.dark,
            groupValue: widget.themeMode,
            onChanged: (m) => m != null ? widget.onThemeModeChanged(m) : null,
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              widget.strings.settingsLanguage,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          RadioListTile<String>(
            title: Text(widget.strings.langSystem),
            value: 'system',
            groupValue: widget.languagePref,
            onChanged: (v) => v != null ? widget.onLanguageChanged(v) : null,
          ),
          RadioListTile<String>(
            title: Text(widget.strings.langGreek),
            value: 'el',
            groupValue: widget.languagePref,
            onChanged: (v) => v != null ? widget.onLanguageChanged(v) : null,
          ),
          RadioListTile<String>(
            title: Text(widget.strings.langEnglish),
            value: 'en',
            groupValue: widget.languagePref,
            onChanged: (v) => v != null ? widget.onLanguageChanged(v) : null,
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Πηγή επαφών',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (_loadingSources)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_availableSources.isEmpty)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Δεν βρέθηκαν πολλαπλές πηγές επαφών'),
              subtitle: Text(
                'Θα χρησιμοποιηθούν όλες οι επαφές της συσκευής.',
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Επίλεξε μία ή περισσότερες πηγές. Αν δεν επιλέξεις '
                'καμία, χρησιμοποιούνται όλες. Τα διπλότυπα (ίδιος '
                'αριθμός σε πάνω από μία πηγή) αφαιρούνται αυτόματα.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            ..._availableSources.map((source) => CheckboxListTile(
                  title: Text(source.displayName),
                  value: _selectedSources.contains(source.id),
                  onChanged: (v) => _toggleSource(source.id, v ?? false),
                )),
          ],
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              widget.strings.settingsSync,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          SwitchListTile(
            title: Text(widget.strings.syncEnable),
            subtitle: Text(widget.strings.syncEnableSubtitle),
            value: _syncEnabled,
            onChanged: (v) => setState(() {
              _syncEnabled = v;
              _saved = false;
            }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _urlController,
              onChanged: (_) => setState(() => _saved = false),
              decoration: InputDecoration(
                labelText: widget.strings.syncServerUrl,
                hintText: 'https://mysync.example.com',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _apiKeyController,
              onChanged: (_) => setState(() => _saved = false),
              obscureText: true,
              decoration: InputDecoration(
                labelText: widget.strings.syncApiKey,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: _save,
              icon: Icon(_saved ? Icons.check : Icons.save_outlined),
              label: Text(_saved ? widget.strings.saved : widget.strings.save),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

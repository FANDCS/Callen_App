import 'package:flutter/material.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../utils/app_strings.dart';

const bool _showOnlineBackupSection = false;

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
  late final TextEditingController _deviceIdController;
  late final TextEditingController _encryptionPasswordController;
  bool _syncEnabled = false;
  bool _saved = false;
  String _syncBackend = 'supabase';
  List<ContactSource> _availableSources = [];
  late Set<String> _selectedSources;
  bool _loadingSources = true;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.store.syncServerUrl);
    _apiKeyController = TextEditingController(text: widget.store.syncApiKey);
    _deviceIdController = TextEditingController(text: widget.store.syncDeviceId);
    _encryptionPasswordController =
        TextEditingController(text: widget.store.syncEncryptionPassword);
    _syncEnabled = widget.store.syncEnabled;
    _syncBackend = widget.store.syncBackend;
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

  String _sourceLabel(ContactSource source) {
    switch (source.id) {
      case deviceSourceId:
        return widget.strings.contactSourceDevice;
      case simSourceId:
        return widget.strings.contactSourceSim;
      default:
        return source.displayName;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    _deviceIdController.dispose();
    _encryptionPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.store.setSyncServerUrl(_urlController.text.trim());
    await widget.store.setSyncApiKey(_apiKeyController.text.trim());
    await widget.store.setSyncDeviceId(_deviceIdController.text.trim());
    await widget.store
        .setSyncEncryptionPassword(_encryptionPasswordController.text);
    await widget.store.setSyncBackend(_syncBackend);
    await widget.store.setSyncEnabled(_syncEnabled);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.settingsSaved)),
    );
  }

  String _serverUrlLabel() {
    switch (_syncBackend) {
      case 'firebase':
        return 'Firebase Project URL / Config';
      case 'pocketbase':
        return 'PocketBase URL';
      default:
        return 'Supabase URL';
    }
  }

  String _apiKeyLabel() {
    switch (_syncBackend) {
      case 'firebase':
        return 'Firebase API Key';
      case 'pocketbase':
        return 'PocketBase Admin Token';
      default:
        return 'Supabase Anon Key';
    }
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              widget.strings.contactSourceTitle,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          if (_loadingSources)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_availableSources.isEmpty)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(widget.strings.contactSourceEmpty),
              subtitle: Text(widget.strings.contactSourceEmptySubtitle),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                widget.strings.contactSourceInstructions,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            ..._availableSources.map((source) => CheckboxListTile(
                  title: Text(_sourceLabel(source)),
                  value: _selectedSources.contains(source.id),
                  onChanged: (v) => _toggleSource(source.id, v ?? false),
                )),
          ],

          if (_showOnlineBackupSection) ...[
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
              child: DropdownButtonFormField<String>(
                initialValue: _syncBackend,
                decoration: InputDecoration(
                  labelText: widget.strings.syncBackendProvider,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'firebase', child: Text('Firebase')),
                  DropdownMenuItem(value: 'supabase', child: Text('Supabase')),
                  DropdownMenuItem(value: 'pocketbase', child: Text('PocketBase')),
                ],
                onChanged: (v) => setState(() {
                  _syncBackend = v ?? 'supabase';
                  _saved = false;
                }),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _urlController,
                onChanged: (_) => setState(() => _saved = false),
                decoration: InputDecoration(
                  labelText: _serverUrlLabel(),
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
                  labelText: _apiKeyLabel(),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _deviceIdController,
                onChanged: (_) => setState(() => _saved = false),
                decoration: InputDecoration(
                  labelText: widget.strings.syncDeviceIdLabel,
                  hintText: widget.strings.syncDeviceIdHint,
                  helperText: widget.strings.syncDeviceIdHelper,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _encryptionPasswordController,
                onChanged: (_) => setState(() => _saved = false),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: widget.strings.syncEncryptionPasswordLabel,
                  helperText: widget.strings.syncEncryptionPasswordHelper,
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
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

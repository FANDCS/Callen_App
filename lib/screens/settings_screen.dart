import 'package:flutter/material.dart';
import '../services/contacts_service.dart';
import '../services/local_call_store.dart';
import '../services/settings_store.dart';
import '../services/sync/sync_backend.dart';
import '../services/sync/sync_service.dart';
import '../utils/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final SettingsStore store;
  final AppStrings strings;
  final String languagePref;
  final ValueChanged<String> onLanguageChanged;
  final ContactsService contactsService;
  final LocalCallStore localCallStore;

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.store,
    required this.strings,
    required this.languagePref,
    required this.onLanguageChanged,
    required this.contactsService,
    required this.localCallStore,
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
  bool _syncing = false;

  // ── new settings ──────────────────────────────────────────────────────────
  late bool _confirmIntlCalls;
  late bool _deleteFromAndroid;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.store.syncServerUrl);
    _apiKeyController = TextEditingController(text: widget.store.syncApiKey);
    _deviceIdController = TextEditingController(text: widget.store.syncDeviceId);
    _encryptionPasswordController =
        TextEditingController(text: widget.store.syncEncryptionPassword);
    _syncEnabled = widget.store.syncEnabled;
    _syncBackend = widget.store.syncBackend == 'firebase'
        ? 'supabase'
        : widget.store.syncBackend;
    _selectedSources = widget.store.contactSources.toSet();
    _confirmIntlCalls = widget.store.confirmIntlCalls;
    _deleteFromAndroid = widget.store.deleteFromAndroid;
    _loadSources();
    _fillDefaultDeviceId();
  }

  Future<void> _fillDefaultDeviceId() async {
    if (_deviceIdController.text.trim().isNotEmpty) return;
    final generated = await widget.store.ensureSyncDeviceId();
    if (!mounted) return;
    setState(() => _deviceIdController.text = generated);
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
      if (selected) _selectedSources.add(id);
      else _selectedSources.remove(id);
    });
    widget.store.setContactSources(_selectedSources.toList());
  }

  String _sourceLabel(ContactSource source) {
    switch (source.id) {
      case deviceSourceId: return widget.strings.contactSourceDevice;
      case simSourceId:    return widget.strings.contactSourceSim;
      default:             return source.displayName;
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
    await widget.store.setSyncEncryptionPassword(_encryptionPasswordController.text);
    await widget.store.setSyncBackend(_syncBackend);
    await widget.store.setSyncEnabled(_syncEnabled);
    await widget.store.setConfirmIntlCalls(_confirmIntlCalls);
    await widget.store.setDeleteFromAndroid(_deleteFromAndroid);
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.settingsSaved)),
    );
  }

  Future<void> _syncNow() async {
    await _save();
    setState(() => _syncing = true);
    final service = SyncService(store: widget.store, localStore: widget.localCallStore);
    final result = await service.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    final message = result.ok
        ? '${widget.strings.syncSuccessPrefix} '
            '${widget.strings.syncPushedCount(result.pushed)}, '
            '${widget.strings.syncPulledCount(result.pulled)}'
        : '${widget.strings.syncFailedPrefix} ${result.error}';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _testConnection() async {
    setState(() => _syncing = true);
    try {
      final backend = SyncService(store: widget.store, localStore: widget.localCallStore);
      await widget.store.setSyncServerUrl(_urlController.text.trim());
      await widget.store.setSyncApiKey(_apiKeyController.text.trim());
      await widget.store.setSyncBackend(_syncBackend);
      await backend.testConnection();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.syncConnectionOk)),
      );
    } on SyncBackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.strings.syncFailedPrefix} ${e.message}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.strings.syncFailedPrefix} $e')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  String _serverUrlLabel() {
    switch (_syncBackend) {
      case 'pocketbase': return 'PocketBase URL';
      case 'custom':     return 'Server URL (δικός σου)';
      default:           return 'Supabase URL';
    }
  }

  String _apiKeyLabel() {
    switch (_syncBackend) {
      case 'pocketbase': return 'PocketBase Admin/Auth Token';
      case 'custom':     return 'Authorization header (π.χ. Bearer xyz)';
      default:           return 'Supabase Anon Key';
    }
  }

  // ── section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        children: [
          // ── Appearance ───────────────────────────────────────────────────
          _sectionHeader(s.settingsAppearance),
          RadioListTile<ThemeMode>(
            title: Text(s.langSystem),
            value: ThemeMode.system,
            groupValue: widget.themeMode,
            onChanged: (m) => m != null ? widget.onThemeModeChanged(m) : null,
          ),
          RadioListTile<ThemeMode>(
            title: Text(s.themeLight),
            value: ThemeMode.light,
            groupValue: widget.themeMode,
            onChanged: (m) => m != null ? widget.onThemeModeChanged(m) : null,
          ),
          RadioListTile<ThemeMode>(
            title: Text(s.themeDark),
            value: ThemeMode.dark,
            groupValue: widget.themeMode,
            onChanged: (m) => m != null ? widget.onThemeModeChanged(m) : null,
          ),

          const Divider(height: 32),

          // ── Language ─────────────────────────────────────────────────────
          _sectionHeader(s.settingsLanguage),
          RadioListTile<String>(
            title: Text(s.langSystem),
            value: 'system',
            groupValue: widget.languagePref,
            onChanged: (v) => v != null ? widget.onLanguageChanged(v) : null,
          ),
          RadioListTile<String>(
            title: Text(s.langGreek),
            value: 'el',
            groupValue: widget.languagePref,
            onChanged: (v) => v != null ? widget.onLanguageChanged(v) : null,
          ),
          RadioListTile<String>(
            title: Text(s.langEnglish),
            value: 'en',
            groupValue: widget.languagePref,
            onChanged: (v) => v != null ? widget.onLanguageChanged(v) : null,
          ),

          const Divider(height: 32),

          // ── Calls ─────────────────────────────────────────────────────────
          _sectionHeader(s.settingsCalls),
          SwitchListTile(
            title: Text(s.confirmIntlCalls),
            subtitle: Text(s.confirmIntlCallsSubtitle),
            value: _confirmIntlCalls,
            onChanged: (v) async {
              setState(() => _confirmIntlCalls = v);
              await widget.store.setConfirmIntlCalls(v);
            },
          ),
          const Divider(indent: 16, endIndent: 16),
          _sectionHeader(s.deleteCallSetting),
          RadioListTile<bool>(
            title: Text(s.deleteFromAndroidLog),
            subtitle: Text(s.deleteFromAndroidLogSubtitle),
            value: true,
            groupValue: _deleteFromAndroid,
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _deleteFromAndroid = v);
              await widget.store.setDeleteFromAndroid(v);
            },
          ),
          RadioListTile<bool>(
            title: Text(s.deleteFromAppOnly),
            subtitle: Text(s.deleteFromAppOnlySubtitle),
            value: false,
            groupValue: _deleteFromAndroid,
            onChanged: (v) async {
              if (v == null) return;
              setState(() => _deleteFromAndroid = v);
              await widget.store.setDeleteFromAndroid(v);
            },
          ),

          const Divider(height: 32),

          // ── Contact sources ───────────────────────────────────────────────
          _sectionHeader(s.contactSourceTitle),
          if (_loadingSources)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_availableSources.isEmpty)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(s.contactSourceEmpty),
              subtitle: Text(s.contactSourceEmptySubtitle),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(s.contactSourceInstructions,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            ..._availableSources.map((source) => CheckboxListTile(
                  title: Text(_sourceLabel(source)),
                  value: _selectedSources.contains(source.id),
                  onChanged: (v) => _toggleSource(source.id, v ?? false),
                )),
          ],

          const Divider(height: 32),

          // ── Sync ──────────────────────────────────────────────────────────
          _sectionHeader(s.settingsSync),
          SwitchListTile(
            title: Text(s.syncEnable),
            subtitle: Text(s.syncEnableSubtitle),
            value: _syncEnabled,
            onChanged: (v) => setState(() { _syncEnabled = v; _saved = false; }),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              initialValue: _syncBackend,
              decoration: InputDecoration(
                labelText: s.syncBackendProvider,
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'supabase', child: Text('Supabase')),
                DropdownMenuItem(value: 'pocketbase', child: Text('PocketBase')),
                DropdownMenuItem(
                    value: 'custom',
                    child: Text('Custom REST (δικός σου server)')),
              ],
              onChanged: (v) => setState(() { _syncBackend = v ?? 'supabase'; _saved = false; }),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _urlController,
              onChanged: (_) => setState(() => _saved = false),
              decoration: InputDecoration(
                  labelText: _serverUrlLabel(), border: const OutlineInputBorder()),
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
                  labelText: _apiKeyLabel(), border: const OutlineInputBorder()),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _deviceIdController,
              onChanged: (_) => setState(() => _saved = false),
              decoration: InputDecoration(
                labelText: s.syncDeviceIdLabel,
                hintText: s.syncDeviceIdHint,
                helperText: s.syncDeviceIdHelper,
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
                labelText: s.syncEncryptionPasswordLabel,
                helperText: s.syncEncryptionPasswordHelper,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _syncing ? null : _save,
                    icon: Icon(_saved ? Icons.check : Icons.save_outlined),
                    label: Text(_saved ? s.saved : s.save),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _syncing ? null : _testConnection,
                    icon: const Icon(Icons.wifi_tethering),
                    label: Text(s.syncTestConnection),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.tonalIcon(
              onPressed: (!_syncEnabled || _syncing) ? null : _syncNow,
              icon: _syncing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(s.syncNow),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SettingsStore {
  static const _keyThemeMode = 'theme_mode';
  static const _keyLanguage = 'language';
  static const _keyContactSources = 'contact_sources';
  static const _keySyncServerUrl = 'sync_server_url';
  static const _keySyncApiKey = 'sync_api_key';
  static const _keySyncEnabled = 'sync_enabled';
  static const _keySyncBackend = 'sync_backend';
  static const _keySyncDeviceId = 'sync_device_id';
  static const _keySyncEncryptionPassword = 'sync_encryption_password';
  static const _keySyncLastPulledAt = 'sync_last_pulled_at';

  final SharedPreferences _prefs;
  SettingsStore._(this._prefs);

  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsStore._(prefs);
  }

  String get themeMode => _prefs.getString(_keyThemeMode) ?? 'system';
  Future<void> setThemeMode(String value) =>
      _prefs.setString(_keyThemeMode, value);

  String get language => _prefs.getString(_keyLanguage) ?? 'system';
  Future<void> setLanguage(String value) =>
      _prefs.setString(_keyLanguage, value);

  List<String> get contactSources =>
      _prefs.getStringList(_keyContactSources) ?? [];
  Future<void> setContactSources(List<String> value) =>
      _prefs.setStringList(_keyContactSources, value);

  String get syncServerUrl => _prefs.getString(_keySyncServerUrl) ?? '';
  Future<void> setSyncServerUrl(String value) =>
      _prefs.setString(_keySyncServerUrl, value);

  String get syncApiKey => _prefs.getString(_keySyncApiKey) ?? '';
  Future<void> setSyncApiKey(String value) =>
      _prefs.setString(_keySyncApiKey, value);

  bool get syncEnabled => _prefs.getBool(_keySyncEnabled) ?? false;
  Future<void> setSyncEnabled(bool value) =>
      _prefs.setBool(_keySyncEnabled, value);

  String get syncBackend => _prefs.getString(_keySyncBackend) ?? 'supabase';
  Future<void> setSyncBackend(String value) =>
      _prefs.setString(_keySyncBackend, value);

  String get syncDeviceId => _prefs.getString(_keySyncDeviceId) ?? '';
  Future<void> setSyncDeviceId(String value) =>
      _prefs.setString(_keySyncDeviceId, value);

  /// Επιστρέφει ένα σταθερό αναγνωριστικό για ΑΥΤΗΝ την εγκατάσταση,
  /// δημιουργώντας το (μία φορά) αν δεν υπάρχει ακόμα. Χρησιμοποιείται σαν
  /// `deviceOrigin` στις εγγραφές κλήσεων ώστε να ξέρουμε ποια συσκευή
  /// δημιούργησε ποια εγγραφή, ακόμα κι αν ο χρήστης δεν έχει γράψει ποτέ
  /// τίποτα στο πεδίο "Όνομα/ID αυτής της εγκατάστασης".
  Future<String> ensureSyncDeviceId() async {
    final existing = syncDeviceId;
    if (existing.isNotEmpty) return existing;
    final generated = const Uuid().v4().substring(0, 8);
    await setSyncDeviceId(generated);
    return generated;
  }

  String get syncEncryptionPassword =>
      _prefs.getString(_keySyncEncryptionPassword) ?? '';
  Future<void> setSyncEncryptionPassword(String value) =>
      _prefs.setString(_keySyncEncryptionPassword, value);

  /// Ο χρόνος (UTC) της τελευταίας επιτυχημένης "pull" - χρησιμοποιείται
  /// ως cursor ώστε να ζητάμε από το backend μόνο ό,τι άλλαξε από τότε.
  DateTime? get syncLastPulledAt {
    final raw = _prefs.getString(_keySyncLastPulledAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setSyncLastPulledAt(DateTime value) =>
      _prefs.setString(_keySyncLastPulledAt, value.toUtc().toIso8601String());
}

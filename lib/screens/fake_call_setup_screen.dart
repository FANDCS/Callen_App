import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/app_strings.dart';

const _fakeCallChannel = MethodChannel('gr.fandcs.callen/fakecall');

class FakeCallSetupScreen extends StatefulWidget {
  final AppStrings strings;
  const FakeCallSetupScreen({super.key, required this.strings});

  @override
  State<FakeCallSetupScreen> createState() => _FakeCallSetupScreenState();
}

class _FakeCallSetupScreenState extends State<FakeCallSetupScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.strings.unknownCaller);
  final _numberController = TextEditingController(text: '+30 69XXXXXXXX');
  int _delaySeconds = 15;
  // 'app' = Callen's own screen · 'system' = device phone UI
  String _mode = 'app';
  bool _scheduled = false;
  // null = unknown, true/false from getStatus
  bool? _systemAccountEnabled;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    try {
      final Map result =
          await _fakeCallChannel.invokeMethod('getStatus') as Map;
      if (!mounted) return;
      setState(() {
        _systemAccountEnabled = result['systemCallAccount'] as bool?;
      });
    } catch (_) {}
  }

  /// Opens the system screen where the user picks which SIM/account is used
  /// for calls (same screen as the first-time setup), so they can switch back
  /// to their real SIM after a fake call.
  Future<void> _openSimSettings() async {
    bool opened = false;
    try {
      opened = await _fakeCallChannel.invokeMethod<bool>(
            'openSettings',
            {'target': 'callAccount'},
          ) ??
          false;
    } catch (_) {}
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.restoreSimOpenFailed)),
      );
    }
    await _fetchStatus();
  }

  Future<void> _schedule() async {
    final name = _nameController.text.trim();
    final number = _numberController.text.trim();
    final s = widget.strings;

    await Permission.notification.request();

    // If system mode but account not yet enabled, send the user to settings.
    if (_mode == 'system' && _systemAccountEnabled == false) {
      final opened = await _fakeCallChannel.invokeMethod<bool>(
            'openSettings',
            {'target': 'callAccount'},
          ) ??
          false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? s.callAccountSettingsOpened
                : s.callAccountNotEnabled,
          ),
        ),
      );
      // Re-check after the user may have enabled it.
      await _fetchStatus();
      return;
    }

    await _fakeCallChannel.invokeMethod('schedule', {
      'delaySeconds': _delaySeconds,
      'name': name.isEmpty ? s.unknownCaller : name,
      'number': number,
      'mode': _mode,
    });

    if (!mounted) return;
    setState(() => _scheduled = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.scheduledSnackbar(_delaySeconds))),
    );
    Navigator.of(context).pop();
  }

  Future<void> _cancel() async {
    await _fakeCallChannel.invokeMethod('cancel');
    if (!mounted) return;
    setState(() => _scheduled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.strings.fakeCallCancelled)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.fakeCallTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.fakeCallDescription,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // ── Caller info ────────────────────────────────────────────────
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: s.callerName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: s.callerNumber,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // ── Delay slider ───────────────────────────────────────────────
          Text(
            s.delaySeconds(_delaySeconds),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _delaySeconds.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            label: '$_delaySeconds',
            onChanged: (v) => setState(() => _delaySeconds = v.round()),
          ),
          const SizedBox(height: 24),

          // ── Mode selector ──────────────────────────────────────────────
          Text(
            s.fakeCallMode,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _ModeCard(
            icon: Icons.phone_android_outlined,
            title: s.fakeCallModeApp,
            subtitle: s.fakeCallModeAppSubtitle,
            selected: _mode == 'app',
            onTap: () => setState(() => _mode = 'app'),
          ),
          const SizedBox(height: 8),
          _ModeCard(
            icon: Icons.dialer_sip_outlined,
            title: s.fakeCallModeSystem,
            subtitle: s.fakeCallModeSystemSubtitle,
            selected: _mode == 'system',
            trailing: _mode == 'system'
                ? _AccountStatusBadge(enabled: _systemAccountEnabled, strings: s)
                : null,
            onTap: () => setState(() => _mode = 'system'),
          ),
          if (_mode == 'system' && _systemAccountEnabled == false) ...[
            const SizedBox(height: 8),
            _InfoBanner(
              icon: Icons.warning_amber_rounded,
              color: Colors.orange,
              text: s.callAccountNotEnabled,
              actionLabel: s.openSettings,
              onAction: () async {
                await _fakeCallChannel
                    .invokeMethod('openSettings', {'target': 'callAccount'});
                await _fetchStatus();
              },
            ),
          ],
          if (_mode == 'system') ...[
            const SizedBox(height: 8),
            _InfoBanner(
              icon: Icons.sim_card_outlined,
              color: Colors.blue,
              text: s.restoreSimHint,
              actionLabel: s.restoreSimButton,
              onAction: _openSimSettings,
            ),
          ],
          const SizedBox(height: 24),

          // ── Hint: app can be closed ────────────────────────────────────
          _InfoBanner(
            icon: Icons.info_outline,
            color: Colors.blue,
            text: s.fakeCallCloseAppHint,
          ),
          const SizedBox(height: 16),

          // ── Schedule / Cancel buttons ──────────────────────────────────
          FilledButton.icon(
            onPressed: _schedule,
            icon: const Icon(Icons.timer_outlined),
            label: Text(s.schedule),
          ),
          if (_scheduled) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(s.cancelFakeCall),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        color: selected
            ? scheme.primary.withValues(alpha: 0.07)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurface,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (selected)
                Icon(Icons.check_circle, color: scheme.primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountStatusBadge extends StatelessWidget {
  final bool? enabled;
  final AppStrings strings;
  const _AccountStatusBadge({required this.enabled, required this.strings});

  @override
  Widget build(BuildContext context) {
    if (enabled == null) {
      return const SizedBox(
          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Icon(
      enabled! ? Icons.check_circle : Icons.error_outline,
      color: enabled! ? Colors.green : Colors.orange,
      size: 20,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: TextStyle(fontSize: 13, color: color.withValues(alpha: 0.9))),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        fontSize: 13,
                        color: color,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/calls_service.dart';
import '../services/contacts_service.dart';
import '../services/settings_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/phone_utils.dart';

class DialerScreen extends StatefulWidget {
  final CallsService callsService;
  final ContactsService contactsService;
  final SettingsStore store;
  final AppStrings strings;
  const DialerScreen({
    super.key,
    required this.callsService,
    required this.contactsService,
    required this.store,
    required this.strings,
  });

  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final TextEditingController _controller = TextEditingController();
  Map<String, String> _nameByNumber = {};

  @override
  void initState() {
    super.initState();
    _loadContactsLookup();
  }

  Future<void> _loadContactsLookup() async {
    final granted = await widget.contactsService.requestPermission();
    if (!granted) return;
    final contacts = await widget.contactsService.getContacts(
      sourceIds: widget.store.contactSources,
    );
    final map = <String, String>{};
    for (final c in contacts) {
      for (final phone in c.phoneNumbers) {
        map[normalizedPhoneKey(phone.number)] = c.displayName;
      }
    }
    if (!mounted) return;
    setState(() => _nameByNumber = map);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setNumber(String text) {
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onDigit(String digit) {
    _setNumber(_controller.text + digit);
  }

  void _onBackspace() {
    final text = _controller.text;
    if (text.isEmpty) return;
    _setNumber(text.substring(0, text.length - 1));
  }

  Future<void> _onCall() async {
    final number = _controller.text;
    if (number.isEmpty) return;
    await widget.callsService.placeCall(number);
  }

  String? _matchedName(String number) {
    if (number.isEmpty) return null;
    final key = normalizedPhoneKey(number);
    if (key.length < 4) return null;
    return _nameByNumber[key];
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.strings.keypadLetters;
    final digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        children: [
          SizedBox(
            height: 64,
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              showCursor: true,
              keyboardType: TextInputType.none,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 3,
                  ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.strings.dialerHint,
                hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ),
          SizedBox(
            height: 22,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                final matched = _matchedName(value.text);
                if (matched == null) return const SizedBox.shrink();
                return Text(
                  matched,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.3,
              children: digits
                  .map((d) => _DialerKey(
                        label: d,
                        sublabel: letters[d] ?? '',
                        onTap: () => _onDigit(d),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: Row(
              children: [
                const SizedBox(width: 56),
                Expanded(
                  child: Center(
                    child: FloatingActionButton.large(
                      heroTag: 'call-fab',
                      backgroundColor: AppColors.brand,
                      onPressed: _onCall,
                      child: const Icon(Icons.call, size: 30),
                    ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      return IconButton(
                        iconSize: 28,
                        icon: const Icon(Icons.backspace_outlined),
                        onPressed: value.text.isEmpty ? null : _onBackspace,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DialerKey extends StatelessWidget {
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  const _DialerKey({
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Material(
        color: Theme.of(context).cardTheme.color,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          splashColor: AppColors.brand.withValues(alpha: 0.15),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (sublabel.isNotEmpty)
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

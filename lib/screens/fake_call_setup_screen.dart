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

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _schedule() async {
    final name = _nameController.text.trim();
    final number = _numberController.text.trim();
    final s = widget.strings;

    
    
    await Permission.notification.request();

    await _fakeCallChannel.invokeMethod('schedule', {
      'delaySeconds': _delaySeconds,
      'name': name.isEmpty ? s.unknownCaller : name,
      'number': number,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.scheduledSnackbar(_delaySeconds))),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.fakeCallTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.fakeCallDescription, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
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
          FilledButton.icon(
            onPressed: _schedule,
            icon: const Icon(Icons.timer_outlined),
            label: Text(s.schedule),
          ),
        ],
      ),
    );
  }
}

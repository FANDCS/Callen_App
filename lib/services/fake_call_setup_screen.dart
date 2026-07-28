import 'package:flutter/material.dart';
import 'fake_call_screen.dart';

/// Οθόνη ρύθμισης για την "ψεύτικη κλήση" — ο χρήστης διαλέγει
/// ψευδώνυμο/αριθμό καλούντος και μετά από πόσο θα "χτυπήσει".
///
/// ΠΕΡΙΟΡΙΣΜΟΣ: το χρονόμετρο είναι απλό Dart Timer, άρα δουλεύει όσο η
/// εφαρμογή παραμένει ζωντανή (foreground/background) — αν το σύστημα
/// κλείσει εντελώς τη διεργασία, δεν θα ενεργοποιηθεί. Για πλήρη
/// αξιοπιστία (σαν ξυπνητήρι) χρειάζεται scheduled notification με
/// exact alarm permission — ξεχωριστό μελλοντικό βήμα.
class FakeCallSetupScreen extends StatefulWidget {
  const FakeCallSetupScreen({super.key});

  @override
  State<FakeCallSetupScreen> createState() => _FakeCallSetupScreenState();
}

class _FakeCallSetupScreenState extends State<FakeCallSetupScreen> {
  final _nameController = TextEditingController(text: 'Άγνωστος αριθμός');
  final _numberController = TextEditingController(text: '+30 69XXXXXXXX');
  int _delaySeconds = 15;

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  void _schedule() {
    final name = _nameController.text.trim();
    final number = _numberController.text.trim();
    final delay = Duration(seconds: _delaySeconds);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Η ψεύτικη κλήση θα "χτυπήσει" σε $_delaySeconds δευτερόλεπτα — '
        'κράτα την εφαρμογή ανοιχτή.',
        ),
      ),
    );

    Future.delayed(delay, () {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FakeCallScreen(
            callerName: name.isEmpty ? 'Άγνωστος αριθμός' : name,
            callerNumber: number,
          ),
          fullscreenDialog: true,
        ),
      );
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ψεύτικη κλήση')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ρύθμισε πώς θα φαίνεται η εισερχόμενη κλήση και πότε θα '
          '"χτυπήσει".',
          style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Όνομα καλούντος',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _numberController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Αριθμός (εμφανίζεται μόνο)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Καθυστέρηση: $_delaySeconds δευτερόλεπτα',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _delaySeconds.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            label: '$_delaySeconds δ.',
            onChanged: (v) => setState(() => _delaySeconds = v.round()),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _schedule,
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Προγραμματισμός'),
          ),
        ],
      ),
    );
  }
}

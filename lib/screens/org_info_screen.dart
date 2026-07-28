import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

/// In-app σελίδα με πληροφορίες οργανισμού και credits — δεν ανοίγει
/// εξωτερικό browser, όλο το περιεχόμενο είναι μέσα στην εφαρμογή.
class OrgInfoScreen extends StatelessWidget {
  final AppStrings strings;
  const OrgInfoScreen({super.key, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(strings.orgAndContributors)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/icons/fandcs_icon.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'FANDCS',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(strings.orgDescription),
          const SizedBox(height: 8),
          Text(strings.githubLinkSoon, style: const TextStyle(color: Colors.grey)),

          const Divider(height: 40),

          Text(
            strings.contributors.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Λευθέρης Τρόμπακας'),
            subtitle: Text(strings.developer),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('—'),
            subtitle: Text(strings.designer),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

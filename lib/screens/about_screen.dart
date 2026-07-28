import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_strings.dart';
import 'org_info_screen.dart';

class AboutScreen extends StatelessWidget {
  final AppStrings strings;
  const AboutScreen({super.key, required this.strings});

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'android_creator@inbox.vg',
      query: 'subject=Callen - Επικοινωνία',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noEmailApp)),
      );
    }
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotOpen(url))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(strings.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icons/fandcs_icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              strings.appName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(strings.version, style: const TextStyle(color: Colors.grey)),
            ),
          ),
          const SizedBox(height: 32),
          Text(strings.aboutDescription),
          const SizedBox(height: 24),

          ListTile(
            leading: const Icon(Icons.groups_outlined),
            title: Text(strings.orgAndContributors),
            subtitle: Text(strings.orgSubtitle),
            contentPadding: EdgeInsets.zero,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => OrgInfoScreen(strings: strings),
              ),
            ),
          ),
          const Divider(height: 32),

          ListTile(
            leading: const Icon(Icons.code_outlined),
            title: Text(strings.builtWithFlutter),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(strings.licenses),
            contentPadding: EdgeInsets.zero,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: strings.appName,
              applicationVersion: '0.1.0',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(strings.privacyPolicy),
            contentPadding: EdgeInsets.zero,
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(
              context,
              'https://raw.githubusercontent.com/FANDCS/main/refs/heads/main/Privacy_Policy_and_Terms_of_Use.md',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(strings.contact),
            subtitle: const Text('android_creator@inbox.vg'),
            contentPadding: EdgeInsets.zero,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openEmail(context),
          ),
        ],
      ),
    );
  }
}

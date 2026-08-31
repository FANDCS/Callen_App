import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class OrgInfoScreen extends StatelessWidget {
  final AppStrings strings;
  const OrgInfoScreen({super.key, required this.strings});

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
          const SizedBox(height: 16),

          Material(
            color: AppColors.brand.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openUrl(context, 'https://github.com/FANDCS'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.code, size: 20, color: AppColors.brand),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GitHub',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'github.com/FANDCS',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.open_in_new, size: 18, color: AppColors.brand),
                  ],
                ),
              ),
            ),
          ),

          const Divider(height: 40),

          Text(
            strings.contributors.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Android Creator'),
            subtitle: Text(strings.developer),
            contentPadding: EdgeInsets.zero,
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(context, 'https://github.com/AndroidCreator5'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Alex632gr'),
            subtitle: Text(strings.designer),
            contentPadding: EdgeInsets.zero,
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _openUrl(context, 'https://www.instagram.com/alex632gr_'),
          ),
        ],
      ),
    );
  }
}
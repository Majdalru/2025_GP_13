import 'package:flutter/material.dart';
import 'package:flutter_application_1/medmain.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import 'upload_audio_page.dart'; // 🆕 صفحة رفع الصوتيات

class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // 🔹 عناصر التصفح (قابلة للتوسّع بسهولة)
    final items = <_BrowseItem>[
      _BrowseItem(
        title: 'Medication',
        subtitle: '',
        icon: Icons.medication,
        color: cs.secondary,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const Medmain()),
        ),
      ),
      _BrowseItem(
        title: 'Summary',
        subtitle: 'Monthly overview',
        icon: Icons.assignment_outlined,
        color: cs.primary,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MedsSummaryPage()),
        ),
      ),
      _BrowseItem(
        title: 'Location',
        subtitle: 'Live location & last seen',
        icon: Icons.location_on,
        color: Colors.teal,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LocationPage()),
        ),
      ),
      _BrowseItem(
        title: 'Manage access',
        subtitle: '',
        icon: Icons.manage_accounts_rounded,
        color: Colors.indigo,
        onTap: null, // غير قابل للنقر
      ),
      _BrowseItem(
        title: 'Upload Audio for Elderly',
        subtitle: 'Share recordings or stories',
        icon: Icons.upload_file,
        color: const Color(0xFF2A4D69),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UploadAudioPage()),
        ),
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final it = items[index];
        return _BrowseCard(
          leadingBg: it.color.withOpacity(.12),
          leadingIconColor: it.color,
          leadingIcon: it.icon,
          title: it.title,
          subtitle: it.subtitle,
          onTap: it.onTap,
        );
      },
    );
  }
}

/// نموذج بيانات بسيط
class _BrowseItem {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  _BrowseItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// تصميم البطاقة الموحدة
class _BrowseCard extends StatelessWidget {
  final Color leadingBg;
  final Color leadingIconColor;
  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _BrowseCard({
    super.key,
    required this.leadingBg,
    required this.leadingIconColor,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tappable = onTap != null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashFactory: tappable ? InkRipple.splashFactory : NoSplash.splashFactory,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: leadingBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(leadingIcon, color: leadingIconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: tappable ? Colors.black87 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

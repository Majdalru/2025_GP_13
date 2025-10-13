import 'package:flutter/material.dart';
import 'package:flutter_application_1/medmain.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';

class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Medication — غير قابل للنقر
        _browseCard(
          context,
          leadingBg: cs.secondary.withOpacity(.12),
          leadingIcon: Icons.medication,
          leadingIconColor: cs.secondary,
          title: 'Medication',
          subtitle: '',

          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const Medmain(),
              ), // <-- FIXED
            );
          },
        ),

        // Summary — قابل للنقر
        _browseCard(
          context,
          leadingBg: cs.primary.withOpacity(.12),
          leadingIcon: Icons.assignment_outlined,
          leadingIconColor: cs.primary,
          title: 'Summary',
          subtitle: 'Monthly overview',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MedsSummaryPage())),
        ),

        // Location — قابل للنقر
        _browseCard(
          context,
          leadingBg: Colors.teal.withOpacity(.12),
          leadingIcon: Icons.location_on,
          leadingIconColor: Colors.teal,
          title: 'Location',
          subtitle: 'Live location & last seen',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const LocationPage())),
        ),

        // Manage access — غير قابل للنقر (مثل Medication)
        _browseCard(
          context,
          leadingBg: Colors.indigo.withOpacity(.12),
          leadingIcon: Icons.manage_accounts_rounded,
          leadingIconColor: Colors.indigo,
          title: 'Manage access',
          subtitle: '',
          // لا onTap
        ),
      ],
    );
  }

  // بطاقة موحّدة
  Widget _browseCard(
    BuildContext context, {
    required Color leadingBg,
    required Color leadingIconColor,
    required IconData leadingIcon,
    required String title,
    String? subtitle,
    VoidCallback? onTap, // null => غير قابل للنقر
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap, // إن كانت null لن يستجيب
        borderRadius: BorderRadius.circular(18),
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: onTap == null ? Colors.grey.shade400 : Colors.black87,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

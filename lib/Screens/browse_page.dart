import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import '../medmain.dart';
import 'meds_summary_page.dart';
import 'location_page.dart';
import 'share_content_page.dart';
import 'home_shell.dart';
import 'manage_access_page.dart';

class BrowsePage extends StatelessWidget {
  final ElderlyProfile? selectedProfile;

  const BrowsePage({super.key, this.selectedProfile});

  void _showSelectProfileMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.pleaseSelectElderlyProfileFirst,
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final items = <_BrowseItem>[
      _BrowseItem(
        title: AppLocalizations.of(context)!.medications,
        subtitle: AppLocalizations.of(context)!.manageMedicationList,
        icon: Icons.medication,
        color: cs.secondary,
        onTap: () {
          if (selectedProfile != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Medmain(elderlyProfile: selectedProfile!),
              ),
            );
          } else {
            _showSelectProfileMessage(context);
          }
        },
      ),

      _BrowseItem(
        title: AppLocalizations.of(context)!.summary,
        subtitle: AppLocalizations.of(context)!.monthlyOverview,
        icon: Icons.assignment_outlined,
        color: cs.primary,
        onTap: () {
          if (selectedProfile != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    MedsSummaryPage(elderlyId: selectedProfile!.uid),
              ),
            );
          } else {
            _showSelectProfileMessage(context);
          }
        },
      ),

      _BrowseItem(
        title: AppLocalizations.of(context)!.location,
        subtitle: AppLocalizations.of(context)!.liveLocation,
        icon: Icons.location_on,
        color: Colors.teal,
        onTap: () {
          if (selectedProfile != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LocationPage(
                  elderlyId: selectedProfile!.uid,
                ),
              ),
            );
          } else {
            _showSelectProfileMessage(context);
          }
        },
      ),

      _BrowseItem(
        title: AppLocalizations.of(context)!.manageAccess,
        subtitle: AppLocalizations.of(context)!.accessControlDesc,
        icon: Icons.manage_accounts_rounded,
        color: Colors.indigo,
        onTap: () {
          if (selectedProfile != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ManageAccessPage(elderlyId: selectedProfile!.uid),
              ),
            );
          } else {
            _showSelectProfileMessage(context);
          }
        },
      ),

      _BrowseItem(
        title: AppLocalizations.of(context)!.shareWithElderly,
        subtitle: AppLocalizations.of(context)!.shareLifeUpdates,
        icon: Icons.share,
        color: const Color(0xFF2A4D69),
        onTap: () {
          if (selectedProfile != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ShareContentPage(elderlyId: selectedProfile!.uid),
              ),
            );
          } else {
            _showSelectProfileMessage(context);
          }
        },
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

class _BrowseCard extends StatelessWidget {
  final Color leadingBg;
  final Color leadingIconColor;
  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _BrowseCard({
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
        splashFactory:
            tappable ? InkRipple.splashFactory : NoSplash.splashFactory,
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
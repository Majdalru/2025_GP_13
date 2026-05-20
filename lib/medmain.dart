import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'addmed.dart';
import 'models/medication.dart';
import 'Screens/home_shell.dart';
import 'services/medication_scheduler.dart';
import 'widgets/todays_meds_tab.dart';
import 'services/medication_history_service.dart';
import 'widgets/medication_history_page.dart';

// ─── Palette ────────────────────────────────────────────────────────────────
const _kTeal = Color(0xFF4DB6AC);
const _kNavy = Color(0xFF0D2D5D);
const _kBg = Color(0xFFF7F8FA);

// ════════════════════════════════════════════════════════════════════════════
// Medmain — Caregiver medication page
// ════════════════════════════════════════════════════════════════════════════
class Medmain extends StatefulWidget {
  final ElderlyProfile elderlyProfile;
  const Medmain({super.key, required this.elderlyProfile});

  @override
  State<Medmain> createState() => _MedmainState();
}

class _MedmainState extends State<Medmain> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    MedicationScheduler().scheduleAllMedications(widget.elderlyProfile.uid);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateAndAddMedication(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedScreen(elderlyId: widget.elderlyProfile.uid),
      ),
    );
  }

  void _navigateAndEditMedication(Medication medication) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedScreen(
          elderlyId: widget.elderlyProfile.uid,
          medicationToEdit: medication,
        ),
      ),
    );
  }

  Future<void> _deleteMedication(Medication medicationToDelete) async {
    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.elderlyProfile.uid);

    try {
      await MedicationHistoryService().saveToHistory(
        elderlyId: widget.elderlyProfile.uid,
        medication: medicationToDelete,
        reason: 'deleted',
      );
      await docRef.update({
        'medsList': FieldValue.arrayRemove([medicationToDelete.toMap()]),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context)!.medicationDeletedSuccessfully ??
                      'Medication deleted successfully',
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      MedicationScheduler().scheduleAllMedications(widget.elderlyProfile.uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.errorDeletingMedication(e.toString()),
            ),
          ),
        );
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 22,
                      color: _kTeal,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc.medsFor} ${widget.elderlyProfile.name}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _kNavy,
                          ),
                        ),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('medications')
                              .doc(widget.elderlyProfile.uid)
                              .snapshots(),
                          builder: (context, snap) {
                            final count = snap.hasData && snap.data!.exists
                                ? ((snap.data!.data()?['medsList'] as List?)
                                          ?.length ??
                                      0)
                                : 0;
                            return Text(
                              '$count ${loc.medications}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab content ────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: Today's meds
                  TodaysMedsTab(
                    elderlyId: widget.elderlyProfile.uid,
                    isCaregiverView: true,
                  ),
                  // Tab 1: Medication list
                  _CaregiverMedsTab(
                    elderlyId: widget.elderlyProfile.uid,
                    onEdit: _navigateAndEditMedication,
                    onDelete: _deleteMedication,
                    onAddMed: () => _navigateAndAddMedication(context),
                    onHistory: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MedicationHistoryPage(
                          elderlyId: widget.elderlyProfile.uid,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Bottom nav ─────────────────────────────────────────────────────
      bottomNavigationBar: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _NavItem(
                      icon: Icons.today_outlined,
                      activeIcon: Icons.today,
                      label:
                          AppLocalizations.of(context)!.todaysMeds ??
                          "Today's Meds",
                      selected: _tabController.index == 0,
                      onTap: () => _tabController.animateTo(0),
                    ),
                    _NavItem(
                      icon: Icons.medication_outlined,
                      activeIcon: Icons.medication,
                      label:
                          AppLocalizations.of(context)!.medList ?? "Med List",
                      selected: _tabController.index == 1,
                      onTap: () => _tabController.animateTo(1),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Bottom nav item — compact caregiver version
// ════════════════════════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _kTeal.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : icon,
                size: 24,
                color: selected ? _kTeal : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _kTeal : const Color(0xFF9CA3AF),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Segmented control — smaller/compact for caregiver
// ════════════════════════════════════════════════════════════════════════════
class _CaregiverSegmentedControl extends StatefulWidget {
  final TabController tabController;
  const _CaregiverSegmentedControl({required this.tabController});

  @override
  State<_CaregiverSegmentedControl> createState() =>
      _CaregiverSegmentedControlState();
}

class _CaregiverSegmentedControlState
    extends State<_CaregiverSegmentedControl> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.tabController.index;
    widget.tabController.addListener(_onTabChange);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_onTabChange);
    super.dispose();
  }

  void _onTabChange() {
    if (mounted) setState(() => _selectedIndex = widget.tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTab(0, loc.todaysMeds ?? "Today's Meds", Icons.today_outlined),
          _buildTab(1, loc.medList ?? "Med List", Icons.medication_outlined),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String text, IconData icon) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => widget.tabController.animateTo(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color.fromARGB(255, 11, 69, 63)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: _kTeal.withOpacity(0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Caregiver Meds Tab — list view with info popup
// ════════════════════════════════════════════════════════════════════════════
class _CaregiverMedsTab extends StatelessWidget {
  final String elderlyId;
  final void Function(Medication) onEdit;
  final void Function(Medication) onDelete;
  final VoidCallback onHistory;
  final VoidCallback onAddMed;

  const _CaregiverMedsTab({
    required this.elderlyId,
    required this.onEdit,
    required this.onDelete,
    required this.onHistory,
    required this.onAddMed,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      children: [
        // ── Add button + history link ──────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAddMed,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                  label: Text(
                    loc.addNewMedication,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kTeal,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: onHistory,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: _kNavy.withOpacity(0.7),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      loc.medicationHistory,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kNavy.withOpacity(0.7),
                        decoration: TextDecoration.underline,
                        decorationColor: _kNavy.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: _kNavy.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Medication list ────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('medications')
                .doc(elderlyId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _kTeal),
                );
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return _EmptyMeds(onAdd: onAddMed);
              }
              final data = snapshot.data!.data();
              final medsList =
                  (data?['medsList'] as List?)
                      ?.map(
                        (m) => Medication.fromMap(m as Map<String, dynamic>),
                      )
                      .toList() ??
                  [];

              if (medsList.isEmpty) return _EmptyMeds(onAdd: onAddMed);

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: medsList.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (context, index) {
                  final med = medsList[index];
                  return _MedListRow(
                    medication: med,
                    onEdit: () => onEdit(med),
                    onDelete: () => onDelete(med),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Action button helper
// ════════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Empty state
// ════════════════════════════════════════════════════════════════════════════
class _EmptyMeds extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyMeds({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kTeal.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.medication_outlined,
              size: 52,
              color: _kTeal,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            loc.noMedicationsFound,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(loc.addNewMedication),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Medication List Row — name + info chip + edit/delete icons
// ════════════════════════════════════════════════════════════════════════════
class _MedListRow extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedListRow({
    required this.medication,
    required this.onEdit,
    required this.onDelete,
  });

  Color _dotColor() {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF4DB6AC),
      const Color(0xFF7E57C2),
      const Color(0xFF1565C0),
      const Color(0xFFFF8F00),
      const Color(0xFFE91E8C),
    ];
    return colors[medication.name.hashCode.abs() % colors.length];
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          loc.confirmDeletion ?? 'Confirm Deletion',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        content: Text(
          '${loc.areYouSureToDelete ?? "Are you sure you want to delete"} "${medication.name}"?',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: Text(
              loc.delete,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoPopup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MedInfoSheet(
        medication: medication,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _dotColor();
    final loc = AppLocalizations.of(context)!;

    // Build a quick subtitle (times + frequency)
    final timeStr = medication.times.map((t) => t.format(context)).join(' · ');

    return InkWell(
      onTap: () => _showInfoPopup(context),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Colored dot / avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.medication_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 14),

            // Name + times
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2340),
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Info chip
            GestureDetector(
              onTap: () => _showInfoPopup(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _kTeal.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: _kTeal),
                    const SizedBox(width: 4),
                    Text(
                      loc.info ?? 'Info',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // Refill bell — only shown when refillReminder is on
            if (medication.refillReminder)
              Tooltip(
                message: loc.summaryRefillReminder,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 18,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Small icon button helper
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Med Info Bottom Sheet — full details popup
// ════════════════════════════════════════════════════════════════════════════
class _MedInfoSheet extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _MedInfoSheet({
    required this.medication,
    required this.onEdit,
    required this.onDelete,
  });

  Color _accentColor() {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF4DB6AC),
      const Color(0xFF7E57C2),
      const Color(0xFF1565C0),
      const Color(0xFFFF8F00),
      const Color(0xFFE91E8C),
    ];
    return colors[medication.name.hashCode.abs() % colors.length];
  }

  String _translateFreq(String? freq, AppLocalizations loc) {
    switch (freq) {
      case 'Once a day':
        return loc.freqOnce;
      case 'Twice a day':
        return loc.freqTwice;
      case 'Three times a day':
        return loc.freqThree;
      case 'Four times a day':
        return loc.freqFour;
      case 'Custom':
        return loc.freqCustom;
      default:
        return freq ?? loc.na;
    }
  }

  String _translateDay(String day, AppLocalizations loc) {
    switch (day) {
      case 'Every day':
        return loc.everyDay;
      case 'Sunday':
        return loc.daySunday;
      case 'Monday':
        return loc.dayMonday;
      case 'Tuesday':
        return loc.dayTuesday;
      case 'Wednesday':
        return loc.dayWednesday;
      case 'Thursday':
        return loc.dayThursday;
      case 'Friday':
        return loc.dayFriday;
      case 'Saturday':
        return loc.daySaturday;
      default:
        return day;
    }
  }

  String _translateForm(String? form, AppLocalizations loc) {
    switch (form) {
      case 'Capsule':
        return loc.formCapsule;
      case 'Syrup':
        return loc.formSyrup;
      case 'Cream/Ointment':
        return loc.formCream;
      case 'Eye Drops':
        return loc.formEyeDrops;
      case 'Ear Drops':
        return loc.formEarDrops;
      case 'Nasal Spray':
        return loc.formNasal;
      case 'Injection':
        return loc.formInjection;
      default:
        return form ?? loc.formOther;
    }
  }

  String _durationDisplay(AppLocalizations loc) {
    if (medication.endDate == null) return loc.durOngoingShort;
    final endDt = medication.endDate!.toDate();
    final now = DateTime.now();
    final daysLeft = endDt.difference(now).inDays;
    final formatted = DateFormat('MMM d, yyyy').format(endDt);
    if (daysLeft < 0) return loc.cardExpired(formatted);
    if (daysLeft == 0) return loc.cardEndsToday;
    if (daysLeft == 1) return loc.cardEndsTomorrow;
    return loc.cardUntilDate(formatted, daysLeft);
  }

  bool get _expiringSoon =>
      medication.endDate != null &&
      medication.endDate!.toDate().difference(DateTime.now()).inDays <= 2;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accent = _accentColor();

    final start = medication.createdAt.toDate();
    final now = DateTime.now();
    final isToday =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final locale = Localizations.localeOf(context).languageCode;
    final startFormatted = DateFormat.yMMMd(locale).format(start);
    final startDisplay = isToday
        ? loc.startDateToday(startFormatted)
        : startFormatted;

    final timeString = medication.times
        .map((t) => t.format(context))
        .join('  ·  ');
    final translatedDays = medication.days
        .map((d) => _translateDay(d, loc))
        .join(', ');

    final doseParts = <String>[];
    if (medication.doseForm != null)
      doseParts.add(_translateForm(medication.doseForm, loc));
    if (medication.doseStrength != null && medication.doseStrength!.isNotEmpty)
      doseParts.add(medication.doseStrength!);
    final doseDisplay = doseParts.isEmpty
        ? loc.summaryNotSpecified
        : doseParts.join(' — ');

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Handle ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header strip ─────────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (doseDisplay != (loc.summaryNotSpecified))
                            Text(
                              doseDisplay,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Refill reminder badge
                    if (medication.refillReminder)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Refill',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Scrollable detail rows ────────────────────────────────
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      color: const Color(0xFF1565C0),
                      label: loc.summaryStartDate,
                      value: startDisplay,
                    ),
                    _InfoRow(
                      icon: Icons.timer_outlined,
                      color: _expiringSoon
                          ? Colors.orange.shade700
                          : const Color(0xFF00897B),
                      label: loc.summaryDuration,
                      value: _durationDisplay(loc),
                      valueColor: _expiringSoon ? Colors.orange.shade700 : null,
                    ),
                    _InfoRow(
                      icon: Icons.medical_services_outlined,
                      color: accent,
                      label: loc.summaryDose,
                      value: doseDisplay,
                    ),
                    _InfoRow(
                      icon: Icons.repeat_rounded,
                      color: const Color(0xFF7E57C2),
                      label: loc.summaryFrequency,
                      value: _translateFreq(medication.frequency, loc),
                    ),
                    _InfoRow(
                      icon: Icons.date_range_outlined,
                      color: const Color(0xFFFF8F00),
                      label: loc.summaryDays,
                      value: translatedDays,
                    ),
                    _InfoRow(
                      icon: Icons.access_time_rounded,
                      color: _kTeal,
                      label: loc.summaryTimes,
                      value: timeString,
                    ),
                    if (medication.notes != null &&
                        medication.notes!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.notes_rounded,
                        color: Colors.grey.shade600,
                        label: loc.summaryNotes,
                        value: medication.notes!,
                      ),

                    const SizedBox(height: 8),
                    // ── Action buttons ───────────────────────────────
                    Row(
                      children: [
                        // Edit
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onEdit();
                            },
                            icon: const Icon(Icons.edit_outlined, size: 17),
                            label: Text(
                              loc.edit,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kNavy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Delete
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              onDelete();
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                            ),
                            label: Text(
                              loc.delete,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Close
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          loc.cancel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Detail row inside the info sheet ───────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1A2340),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Keep CustomSegmentedControl for backward compat if referenced elsewhere
// ════════════════════════════════════════════════════════════════════════════
class CustomSegmentedControl extends StatefulWidget {
  final TabController tabController;
  const CustomSegmentedControl({super.key, required this.tabController});

  @override
  State<CustomSegmentedControl> createState() => _CustomSegmentedControlState();
}

class _CustomSegmentedControlState extends State<CustomSegmentedControl> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.tabController.index;
    widget.tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    widget.tabController.removeListener(_handleTabSelection);
    super.dispose();
  }

  void _handleTabSelection() {
    if (mounted) setState(() => _selectedIndex = widget.tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    return _CaregiverSegmentedControl(tabController: widget.tabController);
  }
}

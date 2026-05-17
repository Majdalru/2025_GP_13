import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'addmedeld.dart';
import '../../models/medication.dart';
import '../../services/medication_scheduler.dart';
import '../../widgets/todays_meds_tab.dart';
import '../../services/medication_history_service.dart';
import '../../widgets/medication_history_page.dart';

import '../../widgets/floating_voice_button.dart';
import '../../widgets/arabic_floating_voice_button.dart';

import '../../services/voice_assistant_service.dart';
import '../../services/arabic_voice_assistant_service.dart';

import '../../models/voice_command.dart';
import '../../providers/locale_provider.dart';

import 'package:flutter_application_1/l10n/app_localizations.dart';

// --- Main Page Widget ---
class ElderlyMedicationPage extends StatefulWidget {
  final String elderlyId;

  /// optional initial voice intent coming from home page
  final VoiceCommand? initialCommand;
  final bool isMedicationsEnabled;

  const ElderlyMedicationPage({
    super.key,
    required this.elderlyId,
    this.initialCommand,
    this.isMedicationsEnabled = true,
  });

  @override
  State<ElderlyMedicationPage> createState() => _ElderlyMedicationPageState();
}

class _ElderlyMedicationPageState extends State<ElderlyMedicationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // English voice service
  final VoiceAssistantService _voiceService = VoiceAssistantService();

  // Arabic voice service
  final ArabicVoiceAssistantService _arabicVoiceService =
      ArabicVoiceAssistantService();

  // نحتفظ بقائمة الأدوية المعروضة
  List<Medication> _currentMeds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // ✅ Check and remove expired medications on screen load
    MedicationScheduler().scheduleAllMedications(widget.elderlyId);

    // Handle initial voice command coming from home (add / edit / delete)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final localeProvider = Provider.of<LocaleProvider>(
        context,
        listen: false,
      );
      final isArabic = localeProvider.isArabic;

      switch (widget.initialCommand) {
        case VoiceCommand.addMedication:
          if (isArabic) {
            await _arabicVoiceService.runAddMedicationFlow(widget.elderlyId);
          } else {
            await _voiceService.runAddMedicationFlow(widget.elderlyId);
          }
          break;

        case VoiceCommand.deleteMedication:
          if (isArabic) {
            await _arabicVoiceService.runDeleteMedicationFlow(widget.elderlyId);
          } else {
            await _voiceService.runDeleteMedicationFlow(widget.elderlyId);
          }
          break;

        case VoiceCommand.editMedication:
          if (isArabic) {
            await _arabicVoiceService.runEditMedicationFlow(widget.elderlyId);
          } else {
            await _voiceService.runEditMedicationFlow(widget.elderlyId);
          }
          break;

        default:
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ============================
  // Navigation to Add / Edit
  // ============================

  void _navigateAndAddMedication(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedScreen(elderlyId: widget.elderlyId),
      ),
    );
  }

  void _navigateAndEditMedication(Medication medication) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedScreen(
          elderlyId: widget.elderlyId,
          medicationToEdit: medication,
        ),
      ),
    );
  }

  // ============================
  // Manual delete from button
  // ============================

  Future<void> _deleteMedication(Medication medicationToDelete) async {
    final loc = AppLocalizations.of(context)!;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.deleted,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height * 0.55,
            left: 20,
            right: 20,
          ),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        ),
      );
    }

    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.elderlyId);

    try {
      await MedicationHistoryService().saveToHistory(
        elderlyId: widget.elderlyId,
        medication: medicationToDelete,
        reason: 'deleted',
      );

      await docRef.update({
        'medsList': FieldValue.arrayRemove([medicationToDelete.toMap()]),
      });

      MedicationScheduler().scheduleAllMedications(widget.elderlyId);

      debugPrint('✅ Medication deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting medication: $e');

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

  void _showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.55,
          left: 20,
          right: 20,
        ),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      ),
    );
  }

  // ============================
  // UI
  // ============================

  @override
  Widget build(BuildContext context) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isArabic = localeProvider.isArabic;
    final loc = AppLocalizations.of(context)!;

    // color palette matching home
    const kTeal = Color(0xFF4DB6AC);
    const kBg = Color(0xFFF7F8FA);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 26,
                      color: kTeal,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.medications,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: kTeal,
                          ),
                        ),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('medications')
                              .doc(widget.elderlyId)
                              .snapshots(),
                          builder: (context, snap) {
                            final count = snap.hasData && snap.data!.exists
                                ? ((snap.data!.data()?['medsList'] as List?)
                                          ?.length ??
                                      0)
                                : 0;
                            return Text(
                              isArabic
                                  ? '$count ${loc.medications} · نشط'
                                  : '$count active ${loc.medications}',
                              style: const TextStyle(
                                fontSize: 15,
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

            // ── Tab content ───────────────────────────────────────
            Expanded(
              child: widget.isMedicationsEnabled
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 0: Today's meds
                        TodaysMedsTab(
                          elderlyId: widget.elderlyId,
                          isCaregiverView: false,
                        ),
                        // Tab 1: All medications
                        _AllMedsTab(
                          elderlyId: widget.elderlyId,
                          onEdit: _navigateAndEditMedication,
                          onDelete: _deleteMedication,
                          onAddMed: () => _navigateAndAddMedication(context),
                          onHistory: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MedicationHistoryPage(
                                elderlyId: widget.elderlyId,
                                isElderlyView: true,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : TodaysMedsTab(
                      elderlyId: widget.elderlyId,
                      isCaregiverView: false,
                    ),
            ),
          ],
        ),
      ),

      // ── Bottom navigation (Today / All) ───────────────────────
      bottomNavigationBar: widget.isMedicationsEnabled
          ? AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          _NavItem(
                            icon: Icons.today_outlined,
                            activeIcon: Icons.today,
                            label: loc.todaysMeds,
                            selected: _tabController.index == 0,
                            onTap: () => _tabController.animateTo(0),
                          ),
                          _NavItem(
                            icon: Icons.medication_outlined,
                            activeIcon: Icons.medication,
                            label: loc.medications,
                            selected: _tabController.index == 1,
                            onTap: () => _tabController.animateTo(1),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          : null,

      // Voice button in medications page
      floatingActionButton: isArabic
          ? ArabicFloatingVoiceButton(
              customGreeting:
                  "أنت الآن في صفحة الأدوية. أستطيع مساعدتك في إضافة دواء أو تعديل دواء أو حذف دواء. ماذا تريد؟ يمكنك قول أضف دواء أو عدل دواء أو احذف دواء.",
              customErrorResponse:
                  "لم أفهم طلبك. يمكنك قول أضف دواء أو عدل دواء أو احذف دواء.",
              onCommand: (command) async {
                switch (command) {
                  case VoiceCommand.addMedication:
                    if (!widget.isMedicationsEnabled) {
                      await _arabicVoiceService.speak(
                        AppLocalizations.of(
                          context,
                        )!.featureDisabledByCaregiver,
                      );
                      break;
                    }
                    await _arabicVoiceService.runAddMedicationFlow(
                      widget.elderlyId,
                    );
                    break;

                  case VoiceCommand.deleteMedication:
                    if (!widget.isMedicationsEnabled) {
                      await _arabicVoiceService.speak(
                        AppLocalizations.of(
                          context,
                        )!.featureDisabledByCaregiver,
                      );
                      break;
                    }
                    await _arabicVoiceService.runDeleteMedicationFlow(
                      widget.elderlyId,
                    );
                    break;

                  case VoiceCommand.editMedication:
                    if (!widget.isMedicationsEnabled) {
                      await _arabicVoiceService.speak(
                        AppLocalizations.of(
                          context,
                        )!.featureDisabledByCaregiver,
                      );
                      break;
                    }
                    await _arabicVoiceService.runEditMedicationFlow(
                      widget.elderlyId,
                    );
                    break;

                  case VoiceCommand.goToMedication:
                    await _arabicVoiceService.speak(
                      "أنت بالفعل في صفحة الأدوية. يمكنك قول أضف دواء أو عدل دواء أو احذف دواء.",
                    );
                    break;

                  case VoiceCommand.goToHome:
                    if (Navigator.canPop(context)) {
                      await _arabicVoiceService.speak(
                        "جاري الرجوع إلى الصفحة الرئيسية.",
                      );
                      Navigator.pop(context);
                    } else {
                      await _arabicVoiceService.speak(
                        "أنت بالفعل في الصفحة الرئيسية.",
                      );
                    }
                    break;

                  default:
                    await _arabicVoiceService.speak(
                      "هذا الأمر الصوتي يعمل من الصفحة الرئيسية. من فضلك ارجع أولًا إلى الصفحة الرئيسية.",
                    );
                    break;
                }
              },
            )
          : FloatingVoiceButton(
              customGreeting:
                  "You are in the medication page. I can help you with adding, editing, or deleting some meds. What would you like to do? You can say add medicine, edit medicine, or delete medicine.",
              customErrorResponse:
                  "I didn't understand. You can say add medication, edit medication, or delete medication.",
              onCommand: (command) async {
                switch (command) {
                  case VoiceCommand.addMedication:
                    if (!widget.isMedicationsEnabled) {
                      await _voiceService.speak(
                        AppLocalizations.of(
                          context,
                        )!.featureDisabledByCaregiver,
                      );
                      break;
                    }
                    await _voiceService.runAddMedicationFlow(widget.elderlyId);
                    break;

                  case VoiceCommand.deleteMedication:
                    if (!widget.isMedicationsEnabled) {
                      await _voiceService.speak(
                        AppLocalizations.of(
                          context,
                        )!.featureDisabledByCaregiver,
                      );
                      break;
                    }
                    await _voiceService.runDeleteMedicationFlow(
                      widget.elderlyId,
                    );
                    break;

                  case VoiceCommand.editMedication:
                    if (!widget.isMedicationsEnabled) {
                      await _voiceService.speak(
                        AppLocalizations.of(
                          context,
                        )!.featureDisabledByCaregiver,
                      );
                      break;
                    }
                    await _voiceService.runEditMedicationFlow(widget.elderlyId);
                    break;

                  case VoiceCommand.goToMedication:
                    await _voiceService.speak(
                      "You are already on your medications page. You can say add medicine, edit medicine, or delete medicine.",
                    );
                    break;

                  case VoiceCommand.goToHome:
                    if (Navigator.canPop(context)) {
                      await _voiceService.speak("Going back to the home page.");
                      Navigator.pop(context);
                    } else {
                      await _voiceService.speak(
                        "You are already on the home page.",
                      );
                    }
                    break;

                  default:
                    await _voiceService.speak(
                      "This voice command works from the home page. Please go back to home first.",
                    );
                    break;
                }
              },
            ),
    );
  }
} // ══════════════════════════════════════════════════════════════

// Bottom nav item
// ══════════════════════════════════════════════════════════════
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
    const kTeal = Color(0xFF4DB6AC);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kTeal.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? activeIcon : icon,
                size: 28,
                color: selected ? kTeal : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? kTeal : const Color(0xFF9CA3AF),
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

// ══════════════════════════════════════════════════════════════
// All Medications Tab — with filter chips
// ══════════════════════════════════════════════════════════════
class _AllMedsTab extends StatefulWidget {
  final String elderlyId;
  final void Function(Medication) onEdit;
  final void Function(Medication) onDelete;
  final VoidCallback onHistory;
  final VoidCallback onAddMed;

  const _AllMedsTab({
    required this.elderlyId,
    required this.onEdit,
    required this.onDelete,
    required this.onHistory,
    required this.onAddMed,
  });

  @override
  State<_AllMedsTab> createState() => _AllMedsTabState();
}

class _AllMedsTabState extends State<_AllMedsTab> {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    const kTeal = Color(0xFF4DB6AC);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Add medication button ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            height: 62,
            child: ElevatedButton.icon(
              onPressed: widget.onAddMed,
              icon: const Icon(Icons.add_circle_outline, size: 28),
              label: Text(
                loc.addNewMedication,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kTeal,
                foregroundColor: Colors.white,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),

        // ── History link ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: widget.onHistory,
              icon: const Icon(Icons.history_rounded, size: 24),
              label: Text(loc.medicationHistory),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0D2D5D),
                side: const BorderSide(color: Color(0xFF0D2D5D), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),

        // ── Medications list ───────────────────────────────────
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('medications')
                .doc(widget.elderlyId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(
                  child: Text(
                    loc.noMedicationsFound,
                    style: const TextStyle(fontSize: 18),
                  ),
                );
              }
              final data = snapshot.data!.data();
              final allMeds =
                  (data?['medsList'] as List?)
                      ?.map(
                        (m) => Medication.fromMap(m as Map<String, dynamic>),
                      )
                      .toList() ??
                  [];

              //final filtered = _applyFilter(allMeds);

              if (allMeds.isEmpty) {
                return Center(
                  child: Text(
                    loc.noMedicationsFound,
                    style: const TextStyle(fontSize: 18),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: allMeds.length,
                itemBuilder: (context, index) {
                  final med = allMeds[index];
                  return MedicationCard(
                    medication: med,
                    onEdit: () => widget.onEdit(med),
                    onDelete: () => widget.onDelete(med),
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

// // --- CUSTOM TAB BAR WIDGET ---
// class CustomSegmentedControl extends StatefulWidget {
//   final TabController tabController;
//   const CustomSegmentedControl({super.key, required this.tabController});

//   @override
//   State<CustomSegmentedControl> createState() => _CustomSegmentedControlState();
// }

// class _CustomSegmentedControlState extends State<CustomSegmentedControl> {
//   late int _selectedIndex;

//   @override
//   void initState() {
//     super.initState();
//     _selectedIndex = widget.tabController.index;
//     widget.tabController.addListener(_handleTabSelection);
//   }

//   @override
//   void dispose() {
//     widget.tabController.removeListener(_handleTabSelection);
//     super.dispose();
//   }

//   void _handleTabSelection() {
//     setState(() {
//       _selectedIndex = widget.tabController.index;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.all(24),
//       padding: const EdgeInsets.all(6),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.15),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           _buildTab(0, AppLocalizations.of(context)!.todaysMeds),
//           _buildTab(1, AppLocalizations.of(context)!.medications),
//         ],
//       ),
//     );
//   }

//   Widget _buildTab(int index, String text) {
//     final bool isSelected = _selectedIndex == index;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () {
//           widget.tabController.animateTo(index);
//         },
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 300),
//           padding: const EdgeInsets.symmetric(vertical: 20),
//           decoration: BoxDecoration(
//             color: isSelected ? const Color(0xFF5FA5A0) : Colors.transparent,
//             borderRadius: BorderRadius.circular(18),
//             boxShadow: isSelected
//                 ? [
//                     BoxShadow(
//                       color: const Color(0xFF5FA5A0).withOpacity(0.3),
//                       blurRadius: 8,
//                       offset: const Offset(0, 3),
//                     ),
//                   ]
//                 : [],
//           ),
//           child: Text(
//             text,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: isSelected ? Colors.white : const Color(0xFF616161),
//               fontWeight: FontWeight.bold,
//               fontSize: 22,
//               letterSpacing: 0.5,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// ══════════════════════════════════════════════════════════════
// Medication Card — redesigned to match screenshot aesthetic
// ══════════════════════════════════════════════════════════════
class MedicationCard extends StatelessWidget {
  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.onEdit,
    required this.onDelete,
  });

  Future<void> _showDeleteConfirmation(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          loc.confirmDeletion,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Text(
          loc.confirmRemoveFromHistory(medication.name),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              loc.cancel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onDelete();
            },
            child: Text(
              loc.delete,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // pick a color per medication index based on name hash
  Color _iconColor() {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFFFF8F00),
      const Color(0xFF7E57C2),
      const Color(0xFF1565C0),
      const Color(0xFFE91E8C),
    ];
    return colors[medication.name.hashCode.abs() % colors.length];
  }

  Color _iconBg() => _iconColor().withOpacity(0.12);

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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    const kTeal = Color(0xFF4DB6AC);
    const kNavy = Color(0xFF0D2D5D);
    // Label: teal bold; Value: near-black for max readability
    const kLabel = TextStyle(
      fontSize: 19,
      fontWeight: FontWeight.w800,
      color: kTeal,
    );
    const kValue = TextStyle(
      fontSize: 19,
      color: Color(0xFF1A1A1A),
      height: 1.5,
    );

    final timeString = medication.times
        .map((t) => t.format(context))
        .join('  ·  ');

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

    String durationDisplay;
    if (medication.endDate == null) {
      durationDisplay = loc.durOngoingShort;
    } else {
      final endDt = medication.endDate!.toDate();
      final daysLeft = endDt.difference(now).inDays;
      final formatted = DateFormat('MMM d, yyyy').format(endDt);
      if (daysLeft < 0)
        durationDisplay = loc.cardExpired(formatted);
      else if (daysLeft == 0)
        durationDisplay = loc.cardEndsToday;
      else if (daysLeft == 1)
        durationDisplay = loc.cardEndsTomorrow;
      else
        durationDisplay = loc.cardUntilDate(formatted, daysLeft);
    }
    final durationExpiringSoon =
        medication.endDate != null &&
        medication.endDate!.toDate().difference(now).inDays <= 2;

    final doseParts = <String>[];
    if (medication.doseForm != null)
      doseParts.add(_translateForm(medication.doseForm, loc));
    if (medication.doseStrength != null && medication.doseStrength!.isNotEmpty)
      doseParts.add(medication.doseStrength!);
    final doseDisplay = doseParts.isEmpty
        ? loc.summaryNotSpecified
        : doseParts.join(' — ');

    final translatedDays = medication.days
        .map((d) => _translateDay(d, loc))
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kTeal.withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top: icon + name ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _iconBg(),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: _iconColor(),
                    size: 34,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      medication.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Divider(
              height: 1,
              thickness: 1,
              color: kTeal.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 14),

          // ── Info block ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: kValue,
                    children: [
                      TextSpan(
                        text: '${loc.summaryStartDate}: ',
                        style: kLabel,
                      ),
                      TextSpan(text: startDisplay),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: kValue,
                    children: [
                      TextSpan(text: '${loc.summaryDuration}: ', style: kLabel),
                      TextSpan(
                        text: durationDisplay,
                        style: kValue.copyWith(
                          color: durationExpiringSoon
                              ? Colors.orange.shade800
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: kValue,
                    children: [
                      TextSpan(text: '${loc.summaryDose}: ', style: kLabel),
                      TextSpan(text: doseDisplay),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: kValue,
                    children: [
                      TextSpan(text: '${loc.frequency}: ', style: kLabel),
                      TextSpan(text: _translateFreq(medication.frequency, loc)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: kValue,
                    children: [
                      TextSpan(text: '${loc.days}: ', style: kLabel),
                      TextSpan(text: translatedDays),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: kValue,
                    children: [
                      TextSpan(text: '${loc.times}: ', style: kLabel),
                      TextSpan(text: timeString),
                    ],
                  ),
                ),
                if (medication.notes != null &&
                    medication.notes!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      style: kValue,
                      children: [
                        TextSpan(text: '${loc.notes}: ', style: kLabel),
                        TextSpan(text: medication.notes!),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: kTeal.withOpacity(0.2)),

          // ── Rectangular buttons at bottom ───────────────────────
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 22),
                  label: Text(loc.edit),
                  style: TextButton.styleFrom(
                    foregroundColor: kNavy,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 52, color: kTeal.withOpacity(0.2)),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _showDeleteConfirmation(context),
                  icon: const Icon(Icons.delete_outline, size: 22),
                  label: Text(loc.delete),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFD62828),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(18),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

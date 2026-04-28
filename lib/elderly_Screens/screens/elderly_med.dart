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

  const ElderlyMedicationPage({
    super.key,
    required this.elderlyId,
    this.initialCommand,
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: const Color(0xFF1B3A52),
        title: Text(AppLocalizations.of(context)!.medications),
        titleTextStyle: const TextStyle(
          fontSize: 34,
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 42),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: Column(
        children: [
          CustomSegmentedControl(tabController: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Today's meds
                TodaysMedsTab(
                  elderlyId: widget.elderlyId,
                  isCaregiverView: false,
                ),

                // Tab 2: Full list
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _navigateAndAddMedication(context),
                        icon: const Icon(Icons.add, size: 32),
                        label: Text(
                          AppLocalizations.of(context)!.addNewMedication,
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF5FA5A0),
                          textStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          minimumSize: const Size.fromHeight(70),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.medications,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B3A52),
                              letterSpacing: 0.5,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicationHistoryPage(
                                  elderlyId: widget.elderlyId,
                                  isElderlyView: true,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.history, size: 26),
                            label: Text(
                              AppLocalizations.of(context)!.medicationHistory,
                              style: const TextStyle(fontSize: 20),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF5FA5A0),
                              side: const BorderSide(
                                color: Color(0xFF5FA5A0),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child:
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('medications')
                                  .doc(widget.elderlyId)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  _currentMeds = [];
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    !snapshot.data!.exists) {
                                  _currentMeds = [];
                                  return Center(
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.noMedicationsFound,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                }
                                if (snapshot.hasError) {
                                  _currentMeds = [];
                                  return Center(
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.errorLoadingMedications,
                                    ),
                                  );
                                }

                                final data = snapshot.data!.data();
                                final medsList =
                                    (data?['medsList'] as List?)
                                        ?.map(
                                          (medMap) => Medication.fromMap(
                                            medMap as Map<String, dynamic>,
                                          ),
                                        )
                                        .toList() ??
                                    [];

                                _currentMeds = medsList;

                                if (medsList.isEmpty) {
                                  return Center(
                                    child: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.noMedicationsFound,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  itemCount: medsList.length,
                                  itemBuilder: (context, index) {
                                    final medication = medsList[index];
                                    return MedicationCard(
                                      medication: medication,
                                      onEdit: () => _navigateAndEditMedication(
                                        medication,
                                      ),
                                      onDelete: () =>
                                          _deleteMedication(medication),
                                    );
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

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
                    await _arabicVoiceService.runAddMedicationFlow(
                      widget.elderlyId,
                    );
                    break;

                  case VoiceCommand.deleteMedication:
                    await _arabicVoiceService.runDeleteMedicationFlow(
                      widget.elderlyId,
                    );
                    break;

                  case VoiceCommand.editMedication:
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
                    await _voiceService.runAddMedicationFlow(widget.elderlyId);
                    break;

                  case VoiceCommand.deleteMedication:
                    await _voiceService.runDeleteMedicationFlow(
                      widget.elderlyId,
                    );
                    break;

                  case VoiceCommand.editMedication:
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
}

// --- CUSTOM TAB BAR WIDGET ---
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
    setState(() {
      _selectedIndex = widget.tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildTab(0, AppLocalizations.of(context)!.todaysMeds),
          _buildTab(1, AppLocalizations.of(context)!.medications),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String text) {
    final bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF5FA5A0) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF5FA5A0).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF616161),
              fontWeight: FontWeight.bold,
              fontSize: 22,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// --- MEDICATION CARD WIDGET ---
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

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            loc.confirmDeletion,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppLocalizations.of(
              context,
            )!.confirmRemoveFromHistory(medication.name),
            style: const TextStyle(fontSize: 20),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                loc.cancel,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: Text(
                loc.delete,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onDelete();
              },
            ),
          ],
        );
      },
    );
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

  // ← helper to format start date
  String _startDateDisplay(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final start = medication.createdAt.toDate();
    final now = DateTime.now();
    final isToday =
        start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final locale = Localizations.localeOf(context).languageCode;
    final formatted = DateFormat.yMMMd(locale).format(start);
    return isToday ? loc.startDateToday(formatted) : formatted;
  }

  String _durationDisplay(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (medication.endDate == null) return loc.durOngoingShort;
    final endDt = medication.endDate!.toDate();
    final now = DateTime.now();
    final daysLeft = endDt.difference(now).inDays;
    final formattedDate = DateFormat('MMM d, yyyy').format(endDt);
    if (daysLeft < 0) return loc.cardExpired(formattedDate);
    if (daysLeft == 0) return loc.cardEndsToday;
    if (daysLeft == 1) return loc.cardEndsTomorrow;
    return loc.cardUntilDate(formattedDate, daysLeft);
  }

  String _doseDisplay(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final parts = <String>[];
    if (medication.doseForm != null)
      parts.add(_translateForm(medication.doseForm, loc));
    if (medication.doseStrength != null && medication.doseStrength!.isNotEmpty)
      parts.add(medication.doseStrength!);
    return parts.isEmpty ? loc.summaryNotSpecified : parts.join(' — ');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final timeString = medication.times
        .map((t) => t.format(context))
        .join(', ');
    final translatedDays = medication.days
        .map((d) => _translateDay(d, loc))
        .join(', ');
    final labelStyle = DefaultTextStyle.of(context).style.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: const Color(0xFF1B3A52),
      letterSpacing: 0.3,
    );
    final valueStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: 22, color: const Color(0xFF212121), height: 1.4);

    return Card(
      elevation: 6,
      margin: const EdgeInsets.only(bottom: 24),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF5FA5A0).withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3A52).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: Color(0xFF1B3A52),
                    size: 40,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B3A52),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFF5FA5A0).withOpacity(0.2),
                  width: 1,
                ),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: valueStyle,
                      children: <TextSpan>[
                        TextSpan(
                          text: '${loc.summaryStartDate}: ',
                          style: labelStyle,
                        ),
                        TextSpan(text: _startDateDisplay(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      style: valueStyle,
                      children: <TextSpan>[
                        TextSpan(
                          text: '${loc.summaryDuration}: ',
                          style: labelStyle,
                        ),
                        TextSpan(
                          text: _durationDisplay(context),
                          style: valueStyle.copyWith(
                            color:
                                medication.endDate != null &&
                                    medication.endDate!
                                            .toDate()
                                            .difference(DateTime.now())
                                            .inDays <=
                                        2
                                ? Colors.orange.shade800
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      style: valueStyle,
                      children: <TextSpan>[
                        TextSpan(
                          text: '${loc.summaryDose}: ',
                          style: labelStyle,
                        ),
                        TextSpan(text: _doseDisplay(context)),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: valueStyle,
                      children: <TextSpan>[
                        TextSpan(text: '${loc.frequency}: ', style: labelStyle),
                        TextSpan(
                          text: _translateFreq(medication.frequency, loc),
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      style: valueStyle,
                      children: <TextSpan>[
                        TextSpan(text: '${loc.days}: ', style: labelStyle),
                        TextSpan(text: translatedDays),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      style: valueStyle,
                      children: <TextSpan>[
                        TextSpan(text: '${loc.times}: ', style: labelStyle),
                        TextSpan(text: timeString),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (medication.notes != null && medication.notes!.isNotEmpty)
                    RichText(
                      text: TextSpan(
                        style: valueStyle,
                        children: <TextSpan>[
                          TextSpan(text: '${loc.notes}: ', style: labelStyle),
                          TextSpan(text: medication.notes!),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 28),
                    label: Text(loc.edit),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF5FA5A0),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDeleteConfirmation(context),
                    icon: const Icon(Icons.delete, size: 28),
                    label: Text(loc.delete),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFFC62828),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

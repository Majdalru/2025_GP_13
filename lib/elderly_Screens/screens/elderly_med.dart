import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'addmedeld.dart';
import '../../models/medication.dart';
import '../../services/medication_scheduler.dart';
import '../../widgets/todays_meds_tab.dart';

// Voice imports
import '../../widgets/floating_voice_button.dart';
import '../../services/voice_assistant_service.dart';
import '../../models/voice_command.dart';

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

  // Voice service (Whisper + GPT)
  final VoiceAssistantService _voiceService = VoiceAssistantService();

  // نحتفظ بقائمة الأدوية المعروضة لو احتجناها مستقبلاً
  List<Medication> _currentMeds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Handle initial voice command coming from home (add / edit / delete)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      switch (widget.initialCommand) {
        case VoiceCommand.addMedication:
          // Run voice-guided medication addition
          _voiceService.runAddMedicationFlow(widget.elderlyId);
          break;

        case VoiceCommand.deleteMedication:
          await _voiceService.runDeleteMedicationFlow(widget.elderlyId);
          break;

        case VoiceCommand.editMedication:
          // Run the complete voice edit flow
          await _voiceService.runEditMedicationFlow(widget.elderlyId);
          break;

        default:
          // no initial command
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

  void _navigateAndAddMedication(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedScreen(elderlyId: widget.elderlyId),
      ),
    );
  }

  void _navigateAndEditMedication(Medication medication) {
    Navigator.push(
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
    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.elderlyId);

    try {
      await docRef.update({
        'medsList': FieldValue.arrayRemove([medicationToDelete.toMap()]),
      });

      // إعادة جدولة الريمايندر بعد الحذف
      await MedicationScheduler().scheduleAllMedications(widget.elderlyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Medication deleted',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 150,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting medication: $e')),
        );
      }
    }
  }

  // ============================
  // UI
  // ============================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        toolbarHeight: 110,
        backgroundColor: const Color(0xFF1B3A52),
        title: const Text("Medications"),
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _navigateAndAddMedication(context),
                        icon: const Icon(Icons.add, size: 32),
                        label: const Text('Add New Medication'),
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
                      const SizedBox(height: 32),
                      const Text(
                        'Medication List',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B3A52),
                          letterSpacing: 0.5,
                        ),
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
                                  return const Center(
                                    child: Text(
                                      "No medications added yet.",
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  );
                                }
                                if (snapshot.hasError) {
                                  _currentMeds = [];
                                  return const Center(
                                    child: Text("Error loading medications."),
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
                                  return const Center(
                                    child: Text(
                                      "No medications added yet.",
                                      style: TextStyle(fontSize: 18),
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

      // ✅ Voice button in medications page
      floatingActionButton: FloatingVoiceButton(
        // ✅ The custom message you wanted:
        customGreeting:
            "You are in the medication page. I can help you with adding, editing, or deleting some meds. What would you like to do?",

        customErrorResponse:
            "I didn't understand. You can say add medication, edit medication, or delete medication.",

        onCommand: (command) async {
          switch (command) {
            case VoiceCommand.addMedication:
              await _voiceService.runAddMedicationFlow(widget.elderlyId);
              break;

            case VoiceCommand.deleteMedication:
              await _voiceService.runDeleteMedicationFlow(widget.elderlyId);
              break;

            case VoiceCommand.editMedication:
              await _voiceService.runEditMedicationFlow(widget.elderlyId);
              break;

            case VoiceCommand.goToMedication:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You are already on the medications page.'),
                ),
              );
              break;

            case VoiceCommand.goToHome:
              if (Navigator.canPop(context)) Navigator.pop(context);
              break;

            default:
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('This command is handled on the home page.'),
                ),
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
        children: [_buildTab(0, "Today's Meds"), _buildTab(1, "Med list")],
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
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Confirm Deletion',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${medication.name}"?',
            style: const TextStyle(fontSize: 20),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
    final timeString = medication.times
        .map((t) => t.format(context))
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
                        TextSpan(text: 'Frequency: ', style: labelStyle),
                        TextSpan(text: medication.frequency ?? 'N/A'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RichText(
                    text: TextSpan(
                      style: valueStyle,
                      children: <TextSpan>[
                        TextSpan(text: 'Times: ', style: labelStyle),
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
                          TextSpan(text: 'Notes: ', style: labelStyle),
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
                    label: const Text('Edit'),
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
                    label: const Text('Delete'),
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

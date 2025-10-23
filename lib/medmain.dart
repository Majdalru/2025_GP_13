import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'addmed.dart';
import 'models/medication.dart'; // Import the new model
import 'Screens/home_shell.dart'; // Import ElderlyProfile to get UID and name
import 'services/medication_scheduler.dart';
import 'widgets/todays_meds_tab.dart';

// --- Main Page Widget ---
class Medmain extends StatefulWidget {
  // This page now requires the profile of the elderly it's managing.
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Navigation now passes the elderlyId to the AddMedScreen
  void _navigateAndAddMedication(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMedScreen(elderlyId: widget.elderlyProfile.uid),
      ),
    );
  }

  void _navigateAndEditMedication(Medication medication) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedScreen(
          elderlyId: widget.elderlyProfile.uid,
          medicationToEdit: medication,
        ),
      ),
    );
  }

  // Firestore deletion logic
  void _deleteMedication(Medication medicationToDelete) async {
    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.elderlyProfile.uid);

    try {
      await docRef.update({
        'medsList': FieldValue.arrayRemove([medicationToDelete.toMap()]),
      });

      // ✅ حدث جدولة التنبيهات بعد الحذف
      await MedicationScheduler().scheduleAllMedications(
        widget.elderlyProfile.uid, // أو widget.elderlyProfile.uid
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication deleted'),
            backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        backgroundColor: const Color.fromRGBO(12, 45, 93, 1),
        title: Text("Meds for ${widget.elderlyProfile.name}"),
        titleTextStyle: const TextStyle(
          fontSize: 22,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () => Navigator.pop(context),
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
                TodaysMedsTab(
                  elderlyId: widget.elderlyProfile.uid,
                  isCaregiverView: true,
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _navigateAndAddMedication(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add New Medication'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.teal,
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Medication List',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child:
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('medications')
                                  .doc(widget.elderlyProfile.uid)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (!snapshot.hasData ||
                                    !snapshot.data!.exists) {
                                  return const Center(
                                    child: Text("No medications added yet."),
                                  );
                                }
                                if (snapshot.hasError) {
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

                                if (medsList.isEmpty) {
                                  return const Center(
                                    child: Text("No medications added yet."),
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
    );
  }
}

// All other widgets (CustomSegmentedControl, MedicationCard, TodaysMedsTab) are unchanged
// and can remain as they were in the original file. I'm keeping them here for completeness.
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color.fromARGB(187, 255, 216, 154),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [_buildTab(0, "Today's Meds"), _buildTab(1, "Med list")],
      ),
    );
  }

  Widget _buildTab(int index, String text) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color.fromARGB(255, 244, 244, 244)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF0A2540)
                  : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

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
          title: const Text('Confirm Deletion'),
          content: Text(
            'Are you sure you want to delete "${medication.name}"?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.blueGrey,
    );
    final valueStyle = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: 16, color: Colors.black87);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.medication, color: Colors.blueGrey, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    medication.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueGrey),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: valueStyle,
                children: <TextSpan>[
                  TextSpan(text: 'Frequency: ', style: labelStyle),
                  TextSpan(text: medication.frequency ?? 'N/A'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: valueStyle,
                children: <TextSpan>[
                  TextSpan(text: 'Times: ', style: labelStyle),
                  TextSpan(text: timeString),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (medication.notes != null && medication.notes!.isNotEmpty)
              Text(
                'Notes: ${medication.notes}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

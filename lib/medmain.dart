import 'package:flutter/material.dart';
import 'addmed.dart';

// --- Medication Class (Model) ---
class Medication {
  final String name;
  final List<String> days;
  final String? frequency;
  final List<TimeOfDay> times;
  final String? notes;

  Medication({
    required this.name,
    required this.days,
    this.frequency,
    required this.times,
    this.notes,
  });
}

// --- Main Page Widget ---
class Medmain extends StatefulWidget {
  const Medmain({super.key});

  @override
  State<Medmain> createState() => _MedmainState();
}

// Add 'SingleTickerProviderStateMixin' for the TabController
class _MedmainState extends State<Medmain> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Medication> _medicationList = [
    Medication(
      name: 'Aspirin',
      days: ['Monday', 'Wednesdayty', 'Friday'],
      frequency: 'Once daily',
      times: [const TimeOfDay(hour: 8, minute: 0)],
      notes: 'Take with a full glass of water.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the TabController
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateAndAddMedication(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddMedScreen()),
    );
    if (result != null && result is Medication) {
      setState(() {
        _medicationList.add(result);
      });
    }
  }

  void _navigateAndEditMedication(Medication medication, int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedScreen(medicationToEdit: medication),
      ),
    );
    if (result != null && result is Medication) {
      setState(() {
        _medicationList[index] = result;
      });
    }
  }

  void _deleteMedication(int index) {
    setState(() {
      _medicationList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        backgroundColor: const Color.fromRGBO(12, 45, 93, 1),
        title: const Text("Medications"),
        titleTextStyle: TextStyle(
          fontSize: 24,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        leading: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10), // Adjust the radius as needed
          ),
        ),
      ),
      // The body now contains the custom tab bar and the TabBarView
      body: Column(
        children: [
          // This is the new custom tab bar widget
          CustomSegmentedControl(tabController: _tabController),
          // The TabBarView shows the content for each tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Content for "Today's Meds" tab
                const Center(
                  child: Text(
                    "Page for Today's Meds",
                    style: TextStyle(fontSize: 20),
                  ),
                ),
                // Content for "Med list" tab
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
                        child: ListView.builder(
                          itemCount: _medicationList.length,
                          itemBuilder: (context, index) {
                            final medication = _medicationList[index];
                            return MedicationCard(
                              medication: medication,
                              onEdit: () =>
                                  _navigateAndEditMedication(medication, index),
                              onDelete: () => _deleteMedication(index),
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

// --- NEW CUSTOM TAB BAR WIDGET ---
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

// --- MEDICATION CARD WIDGET --- (Unchanged)
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

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

enum MedStatus { taken, late, missed }

class TodaysMedication {
  final String name;
  final TimeOfDay time;
  final MedStatus? status; // Null for upcoming meds

  TodaysMedication({required this.name, required this.time, this.status});
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

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
                const TodaysMedsTab(),
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
// --- NEW WIDGETS FOR "TODAY'S MEDS" TAB ---

// The main widget for the "Today's Meds" tab
class TodaysMedsTab extends StatelessWidget {
  const TodaysMedsTab({super.key});

  @override
  Widget build(BuildContext context) {
    // --- Placeholder Data ---
    final List<TodaysMedication> upcomingMeds = [
      TodaysMedication(
        name: 'Aspirin',
        time: const TimeOfDay(hour: 18, minute: 0),
      ),
      TodaysMedication(
        name: 'Vitamin D',
        time: const TimeOfDay(hour: 21, minute: 0),
      ),
    ];

    final List<TodaysMedication> historyMeds = [
      TodaysMedication(
        name: 'Metformin',
        time: const TimeOfDay(hour: 8, minute: 5),
        status: MedStatus.taken,
      ),
      TodaysMedication(
        name: 'Lisinopril',
        time: const TimeOfDay(hour: 8, minute: 20),
        status: MedStatus.late,
      ),
      TodaysMedication(
        name: 'Simvastatin',
        time: const TimeOfDay(hour: 13, minute: 0),
        status: MedStatus.missed,
      ),
      TodaysMedication(
        name: 'Atorvastatin',
        time: const TimeOfDay(hour: 13, minute: 5),
        status: MedStatus.taken,
      ),
    ];
    // --- End of Placeholder Data ---

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _UpcomingMedsCard(meds: upcomingMeds),
        const SizedBox(height: 24),
        _HistoryMedsCard(meds: historyMeds),
      ],
    );
  }
}

// Card for Upcoming Medications
// --- UPDATED WIDGETS FOR "TODAY'S MEDS" TAB ---

// Card for Upcoming Medications (Updated)
class _UpcomingMedsCard extends StatelessWidget {
  final List<TodaysMedication> meds;
  const _UpcomingMedsCard({required this.meds});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Upcoming Medications",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24, thickness: 1), // Line under title
            if (meds.isEmpty)
              const Text(
                "No upcoming medications.",
                style: TextStyle(color: Colors.grey),
              )
            else
              Column(
                children: List.generate(meds.length, (index) {
                  final med = meds[index];
                  final isNext = index == 0;
                  return Opacity(
                    opacity: isNext ? 1.0 : 0.6, // Keep the highlight effect
                    child: _MedicationItemFrame(
                      name: med.name,
                      formattedTime: med.time.format(context),
                    ),
                  );
                }),
              ),
          ],
        ),
      ),
    );
  }
}

// Card for History (Updated)
// Card for History (CORRECTED FOR WIDER FRAMES)
class _HistoryMedsCard extends StatelessWidget {
  final List<TodaysMedication> meds;
  const _HistoryMedsCard({super.key, required this.meds});

  @override
  Widget build(BuildContext context) {
    final taken = meds.where((m) => m.status == MedStatus.taken).toList();
    final late = meds.where((m) => m.status == MedStatus.late).toList();
    final missed = meds.where((m) => m.status == MedStatus.missed).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "History",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24, thickness: 1),
            _buildStatusSection(
              context,
              "Taken",
              taken,
              Colors.green.shade700,
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 16),
            _buildStatusSection(
              context,
              "Late",
              late,
              Colors.orange.shade800,
              Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 16),
            _buildStatusSection(
              context,
              "Missed",
              missed,
              Colors.red.shade700,
              Icons.cancel_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(
    BuildContext context,
    String title,
    List<TodaysMedication> meds,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (meds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Text(
              "None",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Column(
            // The change is here: The Padding widget around _MedicationItemFrame was removed.
            children: meds.map((med) {
              return _MedicationItemFrame(
                name: med.name,
                formattedTime: med.time.format(context),
                color: Colors.grey.shade700,
              );
            }).toList(),
          ),
      ],
    );
  }
}

// Add BuildContext to the method signature
Widget _buildStatusSection(
  BuildContext context,
  String title,
  List<TodaysMedication> meds,
  Color color,
  IconData icon,
) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (meds.isEmpty)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "None",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        )
      else
        Column(
          children: meds.map((med) {
            return Padding(
              padding: const EdgeInsets.only(left: 28.0),
              child: _MedicationItemFrame(
                name: med.name,
                // Now this line works because the method has the context
                formattedTime: med.time.format(context),
                color: Colors.grey.shade700,
              ),
            );
          }).toList(),
        ),
    ],
  );
}

/////////////////////////////////////////

// --- NEW WIDGET FOR INDIVIDUAL MEDICATION FRAME ---
class _MedicationItemFrame extends StatelessWidget {
  final String name;
  final String formattedTime;
  final Color? color; // Optional color for the time text

  const _MedicationItemFrame({
    required this.name,
    required this.formattedTime,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // The "frame" style
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'addmedeld.dart';

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
  MedStatus? status;

  TodaysMedication({required this.name, required this.time, this.status});
}

// --- Main Page Widget ---
class Medmain extends StatefulWidget {
  const Medmain({super.key});

  @override
  State<Medmain> createState() => _MedmainState();
}

class _MedmainState extends State<Medmain> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Medication> _medicationList = [
    Medication(
      name: 'Aspirin',
      days: ['Monday', 'Wednesday', 'Friday'],
      frequency: 'Once daily',
      times: [const TimeOfDay(hour: 8, minute: 0)],
      notes: 'Take with a full glass of water.',
    ),
  ];

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
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(10),
          ),
        ),
      ),
      body: Column(
        children: [
          CustomSegmentedControl(tabController: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const TodaysMedsTab(),
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
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.tabController.animateTo(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF5FA5A0)
                : Colors.transparent,
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
    ).style.copyWith(
      fontSize: 22,
      color: const Color(0xFF212121),
      height: 1.4,
    );

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

// --- TODAY'S MEDS TAB ---
class TodaysMedsTab extends StatefulWidget {
  const TodaysMedsTab({super.key});

  @override
  State<TodaysMedsTab> createState() => _TodaysMedsTabState();
}

class _TodaysMedsTabState extends State<TodaysMedsTab> {
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

  // دالة لتحديد الحالة بناءً على الوقت
  MedStatus? _checkMedicationStatus(TimeOfDay medTime) {
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final medMinutes = medTime.hour * 60 + medTime.minute;
    final difference = currentMinutes - medMinutes;

    if (difference > 180) { // أكثر من 3 ساعات
      return MedStatus.missed;
    } else if (difference > 60) { // أكثر من ساعة
      return MedStatus.late;
    }
    return null; // لا يزال في الوقت المحدد
  }

  void _markAsTaken(int index) {
    setState(() {
      final med = upcomingMeds[index];
      med.status = MedStatus.taken;
      historyMeds.insert(0, med);
      upcomingMeds.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        _UpcomingMedsCard(
          meds: upcomingMeds,
          onMarkAsTaken: _markAsTaken,
          checkStatus: _checkMedicationStatus,
        ),
        const SizedBox(height: 28),
        _HistoryMedsCard(meds: historyMeds),
      ],
    );
  }
}

// --- UPCOMING MEDS CARD ---
class _UpcomingMedsCard extends StatelessWidget {
  final List<TodaysMedication> meds;
  final Function(int) onMarkAsTaken;
  final MedStatus? Function(TimeOfDay) checkStatus;

  const _UpcomingMedsCard({
    required this.meds,
    required this.onMarkAsTaken,
    required this.checkStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5FA5A0).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.alarm,
                    color: Color(0xFF5FA5A0),
                    size: 36,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  "Upcoming",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5FA5A0),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 2),
            if (meds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  "No upcoming medications.",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 22,
                  ),
                ),
              )
            else
              Column(
                children: List.generate(meds.length, (index) {
                  final med = meds[index];
                  final isNext = index == 0;
                  final currentStatus = checkStatus(med.time);
                  
                  return Opacity(
                    opacity: isNext ? 1.0 : 0.6,
                    child: _MedicationItemFrameWithButton(
                      name: med.name,
                      formattedTime: med.time.format(context),
                      isHighlighted: isNext,
                      currentStatus: currentStatus,
                      onTaken: () => onMarkAsTaken(index),
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

// --- HISTORY CARD ---
class _HistoryMedsCard extends StatelessWidget {
  final List<TodaysMedication> meds;
  const _HistoryMedsCard({required this.meds});

  @override
  Widget build(BuildContext context) {
    final taken = meds.where((m) => m.status == MedStatus.taken).toList();
    final late = meds.where((m) => m.status == MedStatus.late).toList();
    final missed = meds.where((m) => m.status == MedStatus.missed).toList();

    return Card(
      elevation: 6,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: const Color(0xFF1B3A52).withOpacity(0.2),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3A52).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.history,
                    color: Color(0xFF1B3A52),
                    size: 36,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  "History",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3A52),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const Divider(height: 32, thickness: 2),
            _buildStatusSection(
              context,
              "Taken",
              taken,
              const Color(0xFF5FA5A0),
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 20),
            _buildStatusSection(
              context,
              "Late",
              late,
              const Color(0xFFEF6C00),
              Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 20),
            _buildStatusSection(
              context,
              "Missed",
              missed,
              const Color(0xFFC62828),
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (meds.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Text(
              "None",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
                fontSize: 20,
              ),
            ),
          )
        else
          Column(
            children: meds.map((med) {
              return _MedicationItemFrame(
                name: med.name,
                formattedTime: med.time.format(context),
                color: color,
              );
            }).toList(),
          ),
      ],
    );
  }
}

// --- MEDICATION ITEM FRAME WITH BUTTON ---
class _MedicationItemFrameWithButton extends StatelessWidget {
  final String name;
  final String formattedTime;
  final bool isHighlighted;
  final MedStatus? currentStatus;
  final VoidCallback onTaken;

  const _MedicationItemFrameWithButton({
    required this.name,
    required this.formattedTime,
    this.isHighlighted = false,
    this.currentStatus,
    required this.onTaken,
  });

  @override
  Widget build(BuildContext context) {
    Color borderColor = const Color(0xFF5FA5A0);
    Color bgColor = const Color(0xFF5FA5A0).withOpacity(0.1);
    String statusText = '';
    
    if (currentStatus == MedStatus.late) {
      borderColor = const Color(0xFFEF6C00);
      bgColor = const Color(0xFFEF6C00).withOpacity(0.1);
      statusText = ' (Late)';
    } else if (currentStatus == MedStatus.missed) {
      borderColor = const Color(0xFFC62828);
      bgColor = const Color(0xFFC62828).withOpacity(0.1);
      statusText = ' (Missed)';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted ? bgColor : const Color(0xFFF5F5F5),
        border: Border.all(
          color: isHighlighted ? borderColor : Colors.grey.shade300,
          width: isHighlighted ? 3 : 2,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name + statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isHighlighted ? 24 : 22,
                    color: const Color(0xFF212121),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                formattedTime,
                style: TextStyle(
                  fontSize: isHighlighted ? 24 : 22,
                  fontWeight: FontWeight.bold,
                  color: borderColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onTaken,
            icon: const Icon(Icons.check_circle, size: 28),
            label: const Text('Mark as Taken'),
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
        ],
      ),
    );
  }
}

// --- MEDICATION ITEM FRAME (للـ History) ---
class _MedicationItemFrame extends StatelessWidget {
  final String name;
  final String formattedTime;
  final Color? color;

  const _MedicationItemFrame({
    required this.name,
    required this.formattedTime,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Color(0xFF212121),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Text(
            formattedTime,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color ?? Theme.of(context).colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

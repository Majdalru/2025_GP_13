import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';
import '../services/medication_scheduler.dart';

class TodaysMedsTab extends StatefulWidget {
  final String elderlyId;
  
  const TodaysMedsTab({super.key, required this.elderlyId});

  @override
  State<TodaysMedsTab> createState() => _TodaysMedsTabState();
}

class _TodaysMedsTabState extends State<TodaysMedsTab> {
  final Map<String, bool> _takenStatus = {};
  final MedicationScheduler _scheduler = MedicationScheduler();

  @override
  void initState() {
    super.initState();
    _loadTakenStatus();
  }

  /// تحميل حالة "تم الأخذ" من SharedPreferences
  Future<void> _loadTakenStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayKey();
    
    setState(() {
      final keys = prefs.getKeys().where((k) => k.startsWith('taken_$today'));
      for (final key in keys) {
        _takenStatus[key] = prefs.getBool(key) ?? false;
      }
    });
  }

  /// حفظ حالة "تم الأخذ"
  Future<void> _saveTakenStatus(String medId, int timeIndex, bool taken) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getTakenKey(medId, timeIndex);
    await prefs.setBool(key, taken);
    
    setState(() {
      _takenStatus[key] = taken;
    });

    // إلغاء التنبيهات التالية
    if (taken) {
      await _scheduler.markMedicationTaken(widget.elderlyId, medId, timeIndex);
    }
  }

  String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  String _getTakenKey(String medId, int timeIndex) {
    return 'taken_${_getTodayKey()}_${medId}_$timeIndex';
  }

  bool _isTaken(String medId, int timeIndex) {
    return _takenStatus[_getTakenKey(medId, timeIndex)] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('medications')
          .doc(widget.elderlyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(
            child: Text(
              'No medications scheduled for today.',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        final data = snapshot.data!.data();
        final medsList = (data?['medsList'] as List?)
            ?.map((m) => Medication.fromMap(m as Map<String, dynamic>))
            .toList() ?? [];

        // تصفية الأدوية لليوم الحالي
        final todayMeds = _filterTodayMedications(medsList);

        if (todayMeds.isEmpty) {
          return const Center(
            child: Text(
              'No medications scheduled for today.',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: todayMeds.length,
          itemBuilder: (context, index) {
            final item = todayMeds[index];
            return _TodayMedicationCard(
              medication: item.medication,
              timeIndex: item.timeIndex,
              time: item.time,
              isTaken: _isTaken(item.medication.id, item.timeIndex),
              onTakenToggled: (taken) {
                _saveTakenStatus(item.medication.id, item.timeIndex, taken);
              },
            );
          },
        );
      },
    );
  }

  /// تصفية الأدوية المجدولة لليوم الحالي
  List<_MedicationTimeSlot> _filterTodayMedications(List<Medication> meds) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayName = _getDayName(today.weekday);

    final result = <_MedicationTimeSlot>[];

    for (final med in meds) {
      // تحقق إذا الدواء مجدول اليوم
      if (!med.days.contains('Every day') && !med.days.contains(todayName)) {
        continue;
      }

      // أضف كل وقت للدواء
      for (int i = 0; i < med.times.length; i++) {
        result.add(_MedicationTimeSlot(
          medication: med,
          time: med.times[i],
          timeIndex: i,
        ));
      }
    }

    // رتب حسب الوقت
    result.sort((a, b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });

    return result;
  }

  String _getDayName(int weekday) {
    const days = [
      '', // weekday starts from 1
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday];
  }
}

/// نموذج بيانات لربط الدواء بوقته
class _MedicationTimeSlot {
  final Medication medication;
  final TimeOfDay time;
  final int timeIndex;

  _MedicationTimeSlot({
    required this.medication,
    required this.time,
    required this.timeIndex,
  });
}

/// بطاقة عرض الدواء مع زر Taken
class _TodayMedicationCard extends StatelessWidget {
  final Medication medication;
  final TimeOfDay time;
  final int timeIndex;
  final bool isTaken;
  final ValueChanged<bool> onTakenToggled;

  const _TodayMedicationCard({
    required this.medication,
    required this.time,
    required this.timeIndex,
    required this.isTaken,
    required this.onTakenToggled,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final schedTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final isPast = schedTime.isBefore(now);
    final isUpcoming = schedTime.isAfter(now) && 
        schedTime.difference(now).inMinutes <= 30;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      color: isTaken 
          ? Colors.green.shade50 
          : (isUpcoming ? Colors.orange.shade50 : Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isTaken 
              ? Colors.green 
              : (isUpcoming ? Colors.orange : Colors.grey.shade300),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with time and status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isTaken 
                        ? Colors.green.withOpacity(0.2)
                        : const Color(0xFF1B3A52).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTaken ? Icons.check_circle : Icons.access_time,
                    color: isTaken ? Colors.green : const Color(0xFF1B3A52),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time.format(context),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B3A52),
                        ),
                      ),
                      if (isUpcoming && !isTaken)
                        Text(
                          'Coming up soon!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (isTaken)
                        const Text(
                          '✓ Taken',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Medication name
            Text(
              medication.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 8),
            
            // Frequency
            if (medication.frequency != null)
              Text(
                'Frequency: ${medication.frequency}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            
            // Notes
            if (medication.notes != null && medication.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, 
                          size: 20, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          medication.notes!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Taken button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isTaken ? null : () => onTakenToggled(true),
                icon: Icon(
                  isTaken ? Icons.check_circle : Icons.check_circle_outline,
                  size: 28,
                ),
                label: Text(
                  isTaken ? 'Medication Taken ✓' : 'Mark as Taken',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTaken ? Colors.grey : const Color(0xFF5FA5A0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: isTaken ? 0 : 4,
                ),
              ),
            ),
            
            // Undo button if taken
            if (isTaken)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton.icon(
                  onPressed: () => onTakenToggled(false),
                  icon: const Icon(Icons.undo, size: 20),
                  label: const Text('Undo'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
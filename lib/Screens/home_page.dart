import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '/medmain.dart';                // صفحة أدوية caregiver
import 'meds_summary_page.dart';       // صفحة الملخص الشهري
import 'location_page.dart';           // صفحة الموقع
import '../models/medication.dart';    // لاستعمال Medication.fromMap

// -------------------- ملخص اليوم (Stream داخلي) --------------------

class _TodaySummary {
  final String? nextName;     // اسم الجرعة الأقرب القادمة (للملخص فقط)
  final DateTime? nextTime;   // وقتها
  final int taken;            // taken_on_time + taken_late
  final int late;             // taken_late فقط
  final int missed;           // missed
  const _TodaySummary({
    this.nextName,
    this.nextTime,
    this.taken = 0,
    this.late = 0,
    this.missed = 0,
  });
}

Stream<_TodaySummary> _todaySummaryStream(String elderlyId) {
  final fs = FirebaseFirestore.instance;
  final now = DateTime.now();
  final todayKey  = DateFormat('yyyy-MM-dd').format(now);
  final todayName = DateFormat('EEEE').format(now); // Monday..Sunday

  // medications/{elderlyId} -> medsList[]
  final medsDocStream = fs.collection('medications').doc(elderlyId).snapshots();

  return medsDocStream.asyncMap((medsSnap) async {
    // 1) جهّز قائمة أدوية اليوم
    final meds = <Medication>[];
    if (medsSnap.exists && medsSnap.data()?['medsList'] != null) {
      final all = (medsSnap.data()!['medsList'] as List)
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList();

      meds.addAll(all.where(
        (m) => m.days.contains('Every day') || m.days.contains(todayName),
      ));
    }
    if (meds.isEmpty) return const _TodaySummary();

    // 2) اللوق اليومي
    Map<String, dynamic> log = {};
    final logDoc = await fs
        .collection('medication_log')
        .doc(elderlyId)
        .collection('daily_log')
        .doc(todayKey)
        .get();
    if (logDoc.exists) log = logDoc.data() ?? {};

    // 3) احسب العدادات واستخرج NextUp (للعنوان فقط)
    int taken = 0, late = 0, missed = 0;
    final nowDT = DateTime.now();
    final doses = <Map<String, dynamic>>[]; // {name, when, status}

    for (final med in meds) {
      for (int i = 0; i < med.times.length; i++) {
        final t = med.times[i];
        final when = DateTime(nowDT.year, nowDT.month, nowDT.day, t.hour, t.minute);
        final logKey = '${med.id}_$i';

        String status = 'upcoming';
        final dlog = log[logKey] as Map<String, dynamic>?;

        if (dlog != null) {
          status = (dlog['status'] as String?) ?? 'upcoming';
        } else {
          // قاعدة: بعد 10 دقائق تصير Missed
          if (nowDT.isAfter(when.add(const Duration(minutes: 10)))) {
            status = 'missed';
          }
        }

        if (status == 'taken_on_time') {
          taken++;
        } else if (status == 'taken_late') {
          taken++;
          late++;
        } else if (status == 'missed') {
          missed++;
        }

        doses.add({'name': med.name, 'when': when, 'status': status});
      }
    }

    // Next Up للملخص فقط (أقرب upcoming >= الآن، وإن ما فيه نعرض أقرب taken_late)
    String? nextName;
    DateTime? nextTime;

    final upcoming = doses
        .where((d) => d['status'] == 'upcoming' && !(d['when'] as DateTime).isBefore(nowDT))
        .toList()
      ..sort((a, b) => (a['when'] as DateTime).compareTo(b['when'] as DateTime));

    if (upcoming.isNotEmpty) {
      nextName = upcoming.first['name'] as String;
      nextTime = upcoming.first['when'] as DateTime;
    } else {
      final lates = doses
          .where((d) => d['status'] == 'taken_late')
          .toList()
        ..sort((a, b) => (a['when'] as DateTime).compareTo(b['when'] as DateTime));
      if (lates.isNotEmpty) {
        nextName = lates.first['name'] as String;
        nextTime = lates.first['when'] as DateTime;
      }
    }

    return _TodaySummary(
      nextName: nextName,
      nextTime: nextTime,
      taken: taken,
      late: late,
      missed: missed,
    );
  });
}

// -------------------- ستريم كل الجرعات القادمة (قائمة بوكسات) --------------------

class _NextDose {
  final String name;
  final DateTime when;
  const _NextDose(this.name, this.when);
}

Stream<List<_NextDose>> _nextDosesStream(String elderlyId) {
  final fs = FirebaseFirestore.instance;
  final now = DateTime.now();
  final todayKey  = DateFormat('yyyy-MM-dd').format(now);
  final todayName = DateFormat('EEEE').format(now);

  final medsDocStream = fs.collection('medications').doc(elderlyId).snapshots();

  return medsDocStream.asyncMap((medsSnap) async {
    // 1) أدوية اليوم
    final meds = <Medication>[];
    if (medsSnap.exists && medsSnap.data()?['medsList'] != null) {
      final all = (medsSnap.data()!['medsList'] as List)
          .map((m) => Medication.fromMap(m as Map<String, dynamic>))
          .toList();
      meds.addAll(all.where(
        (m) => m.days.contains('Every day') || m.days.contains(todayName),
      ));
    }
    if (meds.isEmpty) return const <_NextDose>[];

    // 2) لوق اليوم
    Map<String, dynamic> log = {};
    final logDoc = await fs
        .collection('medication_log')
        .doc(elderlyId)
        .collection('daily_log')
        .doc(todayKey)
        .get();
    if (logDoc.exists) log = logDoc.data() ?? {};

    // 3) كل upcoming التي وقتها >= الآن
    final nowDT = DateTime.now();
    final nextList = <_NextDose>[];

    for (final med in meds) {
      for (int i = 0; i < med.times.length; i++) {
        final t = med.times[i];
        final when = DateTime(nowDT.year, nowDT.month, nowDT.day, t.hour, t.minute);
        final logKey = '${med.id}_$i';

        String status = 'upcoming';
        final dlog = log[logKey] as Map<String, dynamic>?;

        if (dlog != null) {
          status = (dlog['status'] as String?) ?? 'upcoming';
        } else {
          if (nowDT.isAfter(when.add(const Duration(minutes: 10)))) {
            status = 'missed';
          }
        }

        if (status == 'upcoming' && !when.isBefore(nowDT)) {
          nextList.add(_NextDose(med.name, when));
        }
      }
    }

    nextList.sort((a,b) => a.when.compareTo(b.when));
    return nextList;
  });
}

// -------------------- الصفحة الرئيسية (HomePage) --------------------

class HomePage extends StatelessWidget {
  final String elderlyId;                 // ⬅️ مهم: لقراءة بيانات الشخص
  final String elderlyName;
  final VoidCallback onTapArrowToMedsSummary;
  final VoidCallback onTapArrowToMedmain;
  final VoidCallback onTapEmergency;

  const HomePage({
    super.key,
    required this.elderlyId,              // ⬅️ تمرير من HomeShell
    required this.elderlyName,
    required this.onTapArrowToMedsSummary,
    required this.onTapArrowToMedmain,
    required this.onTapEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final formattedDate = DateFormat('d MMM').format(DateTime.now()).toUpperCase();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ===== Emergency Alert =====
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.red.shade600, Colors.red.shade400],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.shade200.withOpacity(.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTapEmergency,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                children: const [
                  Icon(Icons.sos, color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Emergency alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.white),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // ===== Today Card with Brief Medication Info =====
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Today • $formattedDate', // تاريخ اليوم
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Go to Medications',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primary.withOpacity(.10),
                      ),
                      onPressed: onTapArrowToMedmain,
                      icon: Icon(Icons.arrow_forward_rounded, color:Color.fromARGB(255, 1, 42, 75)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Divider(color: Colors.grey.withOpacity(.25), height: 20),
                const SizedBox(height: 12),

                // ==== عرض حقيقي من Firestore (Next Up + Counters) ====
                StreamBuilder<_TodaySummary>(
                  stream: _todaySummaryStream(elderlyId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final s = snap.data ?? const _TodaySummary();

                    // ==== قائمة كل الجرعات القادمة (كل واحدة بوكس) ====
                    return Column(
                      children: [
                        StreamBuilder<List<_NextDose>>(
                          stream: _nextDosesStream(elderlyId),
                          builder: (context, snapNext) {
                            if (snapNext.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            final nexts = snapNext.data ?? const <_NextDose>[];

                            if (nexts.isEmpty) {
                              return _NextMedicationCardReal(
                                medName: 'No upcoming meds',
                                timeText: '--',
                              );
                            }

                            return Column(
                              children: nexts.map((n) {
                                final timeText = DateFormat('h:mm a').format(n.when);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _NextMedicationCardReal(
                                    medName: n.name,
                                    timeText: timeText,
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        _MedicationStatusSummaryRow(
                          taken: s.taken,
                          late: s.late,
                          missed: s.missed,
                        ),

                        const SizedBox(height: 12),
                        Divider(color: Colors.grey.withOpacity(.25), height: 1),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: onTapArrowToMedsSummary,
                            child: const Text(
                              'Monthly Overview',
                              style: TextStyle(fontWeight: FontWeight.bold , color:Color.fromARGB(255, 1, 42, 76)),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              'You are viewing $elderlyName daily meds.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------- ودجت العرض السريع --------------------

class _NextMedicationCardReal extends StatelessWidget {
  final String medName;
  final String timeText;
  const _NextMedicationCardReal({required this.medName, required this.timeText});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.upcoming_outlined, color: const Color.fromARGB(255, 4, 54, 94)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Next Up", style: TextStyle(color: Colors.grey)),
                Text(
                  medName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            timeText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: const Color.fromARGB(255, 2, 49, 87),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationStatusSummaryRow extends StatelessWidget {
  final int taken, late, missed;
  const _MedicationStatusSummaryRow({
    required this.taken,
    required this.late,
    required this.missed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatusItem(
          count: taken,
          label: 'Taken',
          color: Colors.green.shade700,
          icon: Icons.check_circle_outline,
        ),
        _StatusItem(
          count: late,
          label: 'Late',
          color: Colors.orange.shade800,
          icon: Icons.warning_amber_rounded,
        ),
        _StatusItem(
          count: missed,
          label: 'Missed',
          color: Colors.red.shade700,
          icon: Icons.cancel_outlined,
        ),
      ],
    );
  }
}

class _StatusItem extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _StatusItem({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$count ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextSpan(
                text: label,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

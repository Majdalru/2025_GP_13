// MedsSummaryPage.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'med_chart_page.dart'; 

class MedsSummaryPage extends StatefulWidget {
  final String elderlyId; // نفس الـ ID في medication_log/{elderlyId}
  const MedsSummaryPage({super.key, required this.elderlyId});

  @override
  State<MedsSummaryPage> createState() => _MedsSummaryPageState();
}

enum SummaryViewMode { byDay, byMed }

class _MedsSummaryPageState extends State<MedsSummaryPage> {
  DateTime _current = DateTime.now();
  DateTime? _selectedDay;

  SummaryViewMode _mode = SummaryViewMode.byDay;

  int get _daysInMonth {
    final firstNextMonth = DateTime(_current.year, _current.month + 1, 1);
    return firstNextMonth.subtract(const Duration(days: 1)).day;
  }

  int get _weekdayOfFirst => DateTime(_current.year, _current.month, 1).weekday;

  void _goPrevMonth() => setState(() {
        _current = DateTime(_current.year, _current.month - 1, 1);
        _selectedDay = null;
      });

  void _goNextMonth() => setState(() {
        _current = DateTime(_current.year, _current.month + 1, 1);
        _selectedDay = null;
      });

  DateTime? _toDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    if (v is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(v);
      } catch (_) {}
    }
    return null;
  }

  // ---------- Helpers ----------

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? _scheduledOnDay(String schedStr, DateTime dayDate) {
    if (schedStr.isEmpty) return null;
    try {
      final p = schedStr.split(':');
      return DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        int.parse(p[0]),
        int.parse(p[1]),
      );
    } catch (_) {
      return null;
    }
  }

  String _weekdayName(DateTime d) => DateFormat('EEEE').format(d);

  bool _looksLikeDose(Map v) {
    return v.containsKey('scheduledTime') ||
        v.containsKey('medicationName') ||
        v.containsKey('timeIndex') ||
        v.containsKey('status') ||
        v.containsKey('takenAt') ||
        v.containsKey('medicationId');
  }

  ///  تاريخ بداية الدواء المعتمد: createdAt فقط
  DateTime _medStartDate(Map<String, dynamic> med) {
    final raw = med['createdAt'];
    final dt = _toDateTime(raw);
    if (dt != null) return _dateOnly(dt);
    // fallback آمن: اليوم (حتى لا نلوّن الماضي بالخطأ)
    return _dateOnly(DateTime.now());
  }

  bool _isOverdueMissedByClock(String schedHHmm, DateTime dayDate) {
    final schedDT = _scheduledOnDay(schedHHmm, dayDate);
    if (schedDT == null) return false;
    final now = DateTime.now();
    final dayOnly = _dateOnly(dayDate);
    final todayOnly = _dateOnly(now);
    if (dayOnly.isBefore(todayOnly)) return true;
    if (dayOnly.isAtSameMomentAs(todayOnly)) {
      return now.isAfter(schedDT.add(const Duration(minutes: 10)));
    }
    return false;
  }

  // ---------- Streams ----------

  // Logs for current month
  Stream<QuerySnapshot<Map<String, dynamic>>> _monthLogsStream() {
    final first = DateTime(_current.year, _current.month, 1);
    final last = DateTime(_current.year, _current.month, _daysInMonth);
    final startId = DateFormat('yyyy-MM-dd').format(first);
    final endId = DateFormat('yyyy-MM-dd').format(last);

    return FirebaseFirestore.instance
        .collection('medication_log')
        .doc(widget.elderlyId)
        .collection('daily_log')
        .orderBy(FieldPath.documentId)
        .startAt([startId])
        .endAt([endId])
        .snapshots();
  }

  // Meds schedule doc (contains medsList)
  Stream<DocumentSnapshot<Map<String, dynamic>>> _medsStream() {
    return FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.elderlyId)
        .snapshots();
  }

  // ---------- Collect logs-only ----------
  Map<String, List<Map<String, dynamic>>> _collectMonthFromLogs(
      QuerySnapshot<Map<String, dynamic>> snap) {
    final res = <String, List<Map<String, dynamic>>>{};
    for (final doc in snap.docs) {
      final list = <Map<String, dynamic>>[];
      final data = doc.data();

      // top-level array 'doses'
      final dosesField = data['doses'];
      if (dosesField is List) {
        for (final item in dosesField) {
          if (item is Map<String, dynamic> && _looksLikeDose(item)) {
            list.add(item);
          }
        }
      }

      // top-level maps + nested 'doses'
      data.forEach((k, v) {
        if (k == 'doses') return;
        if (v is Map<String, dynamic>) {
          if (_looksLikeDose(v)) list.add(v);
          final nested = v['doses'];
          if (nested is List) {
            for (final it in nested) {
              if (it is Map<String, dynamic> && _looksLikeDose(it)) {
                list.add(it);
              }
            }
          }
        }
      });

      res[doc.id] = list;
    }
    return res;
  }

  // ---------- Merge schedule with logs, inject Missed after createdAt ----------
  Map<String, List<Map<String, dynamic>>> _enrichWithSchedule({
    required Map<String, List<Map<String, dynamic>>> monthLogs,
    required Map<String, dynamic>? medsDocData,
  }) {
    // Start with a copy of logs
    final res = <String, List<Map<String, dynamic>>>{};
    monthLogs.forEach((k, v) => res[k] = [...v]);

    if (medsDocData == null) return res;

    final medsList = medsDocData['medsList'];
    if (medsList is! List) return res;

    final todayOnly = _dateOnly(DateTime.now());

    for (int day = 1; day <= _daysInMonth; day++) {
      final date = DateTime(_current.year, _current.month, day);
      final dayOnly = _dateOnly(date);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final weekday = _weekdayName(date);

      final logsForDay = res[key] ?? <Map<String, dynamic>>[];

      // Build indices for quick matching
      final byPair = <String, Map<String, dynamic>>{};
      final byTime = <String, Map<String, dynamic>>{};
      for (final m in logsForDay) {
        final mid = (m['medicationId'] ?? '').toString();
        final ti = (m['timeIndex'] is int)
            ? m['timeIndex'] as int
            : int.tryParse('${m['timeIndex']}') ?? -1;
        final sk = (m['scheduledTime'] ?? '').toString();
        if (mid.isNotEmpty && ti >= 0) byPair['$mid#$ti'] = m;
        if (sk.isNotEmpty) byTime[sk] = m;
      }

      for (final raw in medsList) {
        if (raw is! Map) continue;
        final med = Map<String, dynamic>.from(raw as Map);
        final medId = (med['id'] ?? '').toString();
        final medName = (med['name'] ?? 'Med').toString();

        // لا نحسب أي شيء قبل createdAt
        final start = _medStartDate(med);
        if (dayOnly.isBefore(start)) continue;

        // Optional: endDate / archived
        final end = _toDateTime(med['endDate']);
        if (end != null && dayOnly.isAfter(_dateOnly(end))) continue;
        if (med['archived'] == true) continue;

        // Does med run this weekday?
        final days = (med['days'] is List)
            ? (med['days'] as List).map((e) => e.toString()).toList()
            : <String>[];
        final runsToday = days.contains('Every day') || days.contains(weekday);
        if (!runsToday) continue;

        // times -> "HH:mm"
        final timesRaw = med['times'];
        final times = <String>[];
        if (timesRaw is List) {
          for (final t in timesRaw) {
            if (t is String && t.contains(':')) {
              times.add(t);
            } else if (t is Map) {
              final hh = int.tryParse('${t['hour'] ?? t['h'] ?? t['HH'] ?? ''}');
              final mm =
                  int.tryParse('${t['minute'] ?? t['m'] ?? t['MM'] ?? ''}');
              if (hh != null && mm != null) {
                times.add(
                    '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}');
              }
            }
          }
        }

        for (int i = 0; i < times.length; i++) {
          final sched = times[i];

          // existing log?
          Map<String, dynamic>? log =
              (medId.isNotEmpty) ? byPair['$medId#$i'] : null;
          log ??= byTime[sched];
          if (log != null) continue;

          // inject Missed iff day is past OR (today & >10m overdue)
          final isPast = dayOnly.isBefore(todayOnly);
          final isOverdueToday = _isOverdueMissedByClock(sched, date);

          if (isPast || isOverdueToday) {
            logsForDay.add({
              'medicationId': medId,
              'medicationName': medName,
              'timeIndex': i,
              'scheduledTime': sched,
              'status': 'missed',
              '_injected': true,
            });
          }
        }
      }

      if (logsForDay.isNotEmpty) {
        logsForDay.sort((a, b) {
          final ai = (a['timeIndex'] is int)
              ? a['timeIndex'] as int
              : int.tryParse('${a['timeIndex']}') ?? 0;
          final bi = (b['timeIndex'] is int)
              ? b['timeIndex'] as int
              : int.tryParse('${b['timeIndex']}') ?? 0;
          if (ai != bi) return ai.compareTo(bi);
          final at = (a['scheduledTime'] ?? '').toString();
          final bt = (b['scheduledTime'] ?? '').toString();
          return at.compareTo(bt);
        });
        res[key] = logsForDay;
      }
    }

    return res;
  }

  // ---------- Aggregation per medication (للوضع الثاني) ----------
  Map<String, int> _aggregateForMed(
    String medId,
    Map<String, List<Map<String, dynamic>>> monthData,
  ) {
    int onTime = 0;
    int late = 0;
    int missed = 0;

    for (final dayList in monthData.values) {
      for (final dose in dayList) {
        if ((dose['medicationId'] ?? '').toString() != medId) continue;
        final status = (dose['status'] ?? '').toString().toLowerCase();

        if (status == 'missed') {
          missed++;
        } else if (status == 'taken_late') {
          late++;
        } else if (status == 'taken_on_time') {
          onTime++;
        }
      }
    }

    return {
      'onTime': onTime,
      'late': late,
      'missed': missed,
    };
  }

  /// 🔹 dailyStats لكل دواء: { 'yyyy-MM-dd' : {onTime, late, missed} }
  Map<String, Map<String, int>> _buildDailyStatsForMed(
    String medId,
    Map<String, List<Map<String, dynamic>>> monthData,
  ) {
    final result = <String, Map<String, int>>{};

    monthData.forEach((dayId, doses) {
      int onTime = 0;
      int late = 0;
      int missed = 0;

      for (final dose in doses) {
        if ((dose['medicationId'] ?? '').toString() != medId) continue;
        final status = (dose['status'] ?? '').toString().toLowerCase();

        if (status == 'missed') {
          missed++;
        } else if (status == 'taken_late') {
          late++;
        } else if (status == 'taken_on_time') {
          onTime++;
        }
      }

      if (onTime > 0 || late > 0 || missed > 0) {
        result[dayId] = {
          'onTime': onTime,
          'late': late,
          'missed': missed,
        };
      }
    });

    return result;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(_current);

    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _monthLogsStream(),
        builder: (context, logsSnap) {
          if (logsSnap.hasError) {
            return Center(child: Text('Error: ${logsSnap.error}'));
          }
          if (!logsSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final monthLogs = _collectMonthFromLogs(logsSnap.data!);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _medsStream(),
            builder: (context, medsSnap) {
              final medsData = medsSnap.data?.data();
              final monthData =
                  _enrichWithSchedule(monthLogs: monthLogs, medsDocData: medsData);
              final cs = Theme.of(context).colorScheme;

              if (_mode == SummaryViewMode.byDay) {
                // ---------- وضع الكالندر ----------
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildModeToggle(cs),
                    const SizedBox(height: 16),

                    // Month header
                    Row(
                      children: [
                        IconButton(
                          onPressed: _goPrevMonth,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                monthName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _goNextMonth,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Weekday headers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        _SummaryDow('Mon'),
                        _SummaryDow('Tue'),
                        _SummaryDow('Wed'),
                        _SummaryDow('Thu'),
                        _SummaryDow('Fri'),
                        _SummaryDow('Sat'),
                        _SummaryDow('Sun'),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Calendar grid
                    _buildCalendarGrid(context, monthData),

                    const SizedBox(height: 12),

                    // Legend
                    _LegendRow(),

                    const SizedBox(height: 16),

                    // Selected day details
                    if (_selectedDay != null) ...[
                      Text(
                        DateFormat('d MMMM').format(_selectedDay!),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...(() {
                        final key =
                            DateFormat('yyyy-MM-dd').format(_selectedDay!);
                        final doses = [...(monthData[key] ?? const [])];
                        if (doses.isEmpty) {
                          return const [Text('No logs for this day')];
                        }

                        doses.sort((a, b) {
                          final ai = (a['timeIndex'] is int)
                              ? a['timeIndex'] as int
                              : int.tryParse('${a['timeIndex']}') ?? 0;
                          final bi = (b['timeIndex'] is int)
                              ? b['timeIndex'] as int
                              : int.tryParse('${b['timeIndex']}') ?? 0;
                          if (ai != bi) return ai.compareTo(bi);
                          final at = (a['scheduledTime'] ?? '').toString();
                          final bt = (b['scheduledTime'] ?? '').toString();
                          return at.compareTo(bt);
                        });

                        return doses.map((m) {
                          final status =
                              (m['status'] ?? '').toString().toLowerCase();
                          final name =
                              (m['medicationName'] ?? 'Med').toString();
                          final sched = (m['scheduledTime'] ?? '').toString();
                          final takenAt = _toDateTime(m['takenAt']);

                          String timeLabel = 'Scheduled $sched';
                          if (takenAt != null) {
                            timeLabel +=
                                ' • Taken ${DateFormat('hh:mm a').format(takenAt)}';
                          }

                          DoseTone tone;
                          if (status == 'missed' ||
                              (takenAt == null &&
                                  _isOverdueMissedByClock(
                                      sched, _selectedDay!))) {
                            tone = DoseTone.missed;
                            if (!timeLabel.contains('Missed')) {
                              timeLabel += ' • Missed (>10m overdue)';
                            }
                          } else if (status == 'taken_late') {
                            tone = DoseTone.late;
                            if (!timeLabel.contains('Taken late')) {
                              timeLabel += ' • Taken late';
                            }
                          } else if (status == 'taken_on_time') {
                            tone = DoseTone.onTime;
                          } else {
                            tone = DoseTone.onTime;
                          }

                          return _SummaryMedStatusRow(
                            name: name,
                            time: timeLabel,
                            tone: tone,
                          );
                        }).toList();
                      })(),
                    ] else
                      const Text('Select a day to view details'),
                  ],
                );
              } else {
                // ---------- وضع الأدوية (per med) ----------
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildModeToggle(cs),
                    const SizedBox(height: 16),

                    //  Month header هنا أيضاً
                    Row(
                      children: [
                        IconButton(
                          onPressed: _goPrevMonth,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: cs.primary.withOpacity(.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                monthName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _goNextMonth,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Medications for this elderly',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (medsData == null ||
                        medsData['medsList'] == null ||
                        (medsData['medsList'] as List).isEmpty)
                      const Text('No medications found')
                    else ...[
                      ...((medsData['medsList'] as List).map((raw) {
                        if (raw is! Map) return const SizedBox.shrink();
                        final med = Map<String, dynamic>.from(raw as Map);
                        final medId = (med['id'] ?? '').toString();
                        final medName =
                            (med['name'] ?? 'Medication').toString();
                        final dosage =
                            (med['dosage'] ?? med['dose'] ?? '').toString();

                        final agg = _aggregateForMed(medId, monthData);
                        final totalTaken =
                            agg['onTime']! + agg['late']! + agg['missed']!;

                        return Card(
                          child: ListTile(
                            title: Text(
                              medName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (dosage.isNotEmpty) Text(dosage),
                                const SizedBox(height: 4),
                                Text(
                                  'On time: ${agg['onTime']}   '
                                  'Late: ${agg['late']}   '
                                  'Missed: ${agg['missed']}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                if (totalTaken == 0)
                                  Text(
                                    'No doses for this month yet',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                        context,
                                      MaterialPageRoute(
                                       builder: (_) => MedChartPage(
                                        elderlyId: widget.elderlyId,
                                        medId: medId,
                                        medName: medName,
                                       initialMonth: _current, // نفس الشهر اللي  في السمّري
                                          ),
                                        ),
                                      );
                              },

                          ),
                        );
                      }).toList()),
                    ],
                  ],
                );
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _ModeToggleButton(
            label: 'By day',
            selected: _mode == SummaryViewMode.byDay,
            onTap: () {
              if (_mode != SummaryViewMode.byDay) {
                setState(() => _mode = SummaryViewMode.byDay);
              }
            },
          ),
          _ModeToggleButton(
            label: 'By medication',
            selected: _mode == SummaryViewMode.byMed,
            onTap: () {
              if (_mode != SummaryViewMode.byMed) {
                setState(() => _mode = SummaryViewMode.byMed);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> monthData,
  ) {
    final leadingEmpty = (_weekdayOfFirst + 6) % 7;
    final totalCells = leadingEmpty + _daysInMonth;
    final rows = (totalCells / 7).ceil();

    final todayKey = _dateOnly(DateTime.now());

    Color? _bgForDay(int day) {
      final d = DateTime(_current.year, _current.month, day);
      final isFuture = _dateOnly(d).isAfter(todayKey);
      final key = DateFormat('yyyy-MM-dd').format(d);
      final doses = monthData[key] ?? const [];

      if (isFuture) return Colors.grey.shade200;
      if (doses.isEmpty) return null;

      bool anyMissed = false;
      bool anyLate = false;
      bool allOnTime = true;

      for (final dose in doses) {
        final status = (dose['status'] ?? '').toString().toLowerCase();
        final takenAt = _toDateTime(dose['takenAt']);
        final sched = (dose['scheduledTime'] ?? '').toString();

        if (status == 'missed' ||
            (takenAt == null && _isOverdueMissedByClock(sched, d))) {
          anyMissed = true;
          allOnTime = false;
          continue;
        }
        if (status == 'taken_late') {
          anyLate = true;
          allOnTime = false;
          continue;
        }
        if (status == 'taken_on_time') {
          // keep allOnTime
        } else {
          allOnTime = false;
        }
      }

      if (anyMissed) return Colors.red.shade600;
      if (anyLate) return Colors.amber.shade700;
      if (allOnTime) return Colors.green.shade600;
      return null;
    }

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNumber = cellIndex - leadingEmpty + 1;

            if (dayNumber < 1 || dayNumber > _daysInMonth) {
              return const _SummaryDayCell.empty();
            }

            final dayDate = DateTime(_current.year, _current.month, dayNumber);
            final isSelected = _selectedDay != null &&
                dayDate.year == _selectedDay!.year &&
                dayDate.month == _selectedDay!.month &&
                dayDate.day == _selectedDay!.day;
            final isToday = _dateOnly(dayDate).isAtSameMomentAs(todayKey);

            return _SummaryDayCell(
              day: dayNumber,
              bgColor: _bgForDay(dayNumber),
              selected: isSelected,
              isToday: isToday,
              onTap: () => setState(() => _selectedDay = dayDate),
            );
          }),
        );
      }),
    );
  }
}

// ---------------- Small widgets ----------------

class _ModeToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeToggleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryDow extends StatelessWidget {
  final String label;
  const _SummaryDow(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style:
              TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SummaryDayCell extends StatelessWidget {
  final int? day;
  final bool selected;
  final bool isToday;
  final Color? bgColor;
  final VoidCallback? onTap;

  const _SummaryDayCell({
    this.day,
    this.selected = false,
    this.isToday = false,
    this.bgColor,
    this.onTap,
    super.key,
  });

  const _SummaryDayCell.empty({super.key})
      : day = null,
        selected = false,
        isToday = false,
        bgColor = null,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const Expanded(child: SizedBox(height: 52));

    final hasColor = bgColor != null;

    final primary = Theme.of(context).colorScheme.primary;
    final Color borderColor = selected
        ? primary
        : (isToday ? primary : Colors.grey.shade300);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasColor ? bgColor!.withOpacity(.95) : null,
              border: Border.all(
                color: borderColor,
                width: (selected || isToday) ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: borderColor.withOpacity(.25),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: hasColor ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== tone-based card =====
enum DoseTone { onTime, late, missed }

class _SummaryMedStatusRow extends StatelessWidget {
  final String name, time;
  final DoseTone tone;

  const _SummaryMedStatusRow({
    super.key,
    required this.name,
    required this.time,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    late final Color base;
    late final IconData icon;
    late final IconData trailingIcon;

    switch (tone) {
      case DoseTone.onTime:
        base = Colors.green.shade600;
        icon = Icons.check_circle;
        trailingIcon = Icons.check;
        break;
      case DoseTone.late:
        base = Colors.amber.shade700;
        icon = Icons.check_circle;
        trailingIcon = Icons.check;
        break;
      case DoseTone.missed:
        base = Colors.red.shade700;
        icon = Icons.cancel;
        trailingIcon = Icons.close;
        break;
    }

    return Card(
      color: base.withOpacity(.08),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: base.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: base),
        ),
        title: Text(
          name,
          style: TextStyle(color: base, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(time),
        trailing: Icon(trailingIcon, color: base),
      ),
    );
  }
}

// Legend
class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: const [
        _LegendItem(color: Color(0xFFD32F2F), label: 'Missed'),
        _LegendItem(color: Color(0xFFF9A825), label: 'Late'),
        _LegendItem(color: Color(0xFF2E7D32), label: 'On time'),
        _LegendItem(color: Color(0xFFEEEEEE), label: 'Upcoming'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

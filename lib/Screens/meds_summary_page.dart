// MedsSummaryPage.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MedsSummaryPage extends StatefulWidget {
  final String elderlyId; // required: same ID used under medication_log/{elderlyId}
  const MedsSummaryPage({super.key, required this.elderlyId});

  @override
  State<MedsSummaryPage> createState() => _MedsSummaryPageState();
}

class _MedsSummaryPageState extends State<MedsSummaryPage> {
  DateTime _current = DateTime.now();
  DateTime? _selectedDay;

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
    return null;
  }

  // Stream for current month using documentId range (yyyy-MM-dd)
  Stream<QuerySnapshot<Map<String, dynamic>>> _monthStream() {
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

  // snapshot → map: yyyy-MM-dd → List<Map> of doses
  Map<String, List<Map<String, dynamic>>> _collectMonth(
      QuerySnapshot<Map<String, dynamic>> snap) {
    final res = <String, List<Map<String, dynamic>>>{};
    for (final doc in snap.docs) {
      final list = <Map<String, dynamic>>[];
      doc.data().forEach((k, v) {
        if (v is Map<String, dynamic>) list.add(v);
      });
      res[doc.id] = list;
    }
    return res;
  }

  // Decide circle background color for a given day
  Color? _bgForDay(int day, Map<String, List<Map<String, dynamic>>> month) {
    final today = DateTime.now();
    final d = DateTime(_current.year, _current.month, day);
    final isFuture = d.isAfter(DateTime(today.year, today.month, today.day));
    final key = DateFormat('yyyy-MM-dd').format(d);
    final doses = month[key] ?? const [];

    if (isFuture) return Colors.grey.shade200; // upcoming (filled light grey)
    if (doses.isEmpty) return null; // past day with no logs → transparent

    final statuses =
        doses.map((m) => (m['status'] ?? '').toString().toLowerCase()).toList();

    final hasMissed = statuses.contains('missed');
    final hasLate = statuses.contains('taken_late');
    final allOnTime =
        statuses.isNotEmpty && statuses.every((s) => s == 'taken_on_time');

    if (hasMissed) return Colors.red.shade600;    // missed
    if (hasLate) return Colors.amber.shade700;    // late
    if (allOnTime) return Colors.green.shade600;  // on time

    // Fallback (mixed unexpected): treat as late
    return Colors.amber.shade700;
  }

  List<Map<String, dynamic>> _dosesFor(
      DateTime day, Map<String, List<Map<String, dynamic>>> month) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final doses = month[key] ?? const [];
    final sorted = [...doses];
    sorted.sort((a, b) {
      final ai = (a['timeIndex'] is int)
          ? a['timeIndex'] as int
          : int.tryParse('${a['timeIndex']}') ?? 0;
      final bi = (b['timeIndex'] is int)
          ? b['timeIndex'] as int
          : int.tryParse('${b['timeIndex']}') ?? 0;
      return ai.compareTo(bi);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(_current);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _monthStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final monthData = _collectMonth(snap.data!);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Month header
              Row(
                children: [
                  IconButton(
                      onPressed: _goPrevMonth,
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          monthName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                      onPressed: _goNextMonth,
                      icon: const Icon(Icons.chevron_right)),
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

              // Legend (style #2)
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
                  final doses = _dosesFor(_selectedDay!, monthData);
                  if (doses.isEmpty) {
                    return const [Text('No logs for this day')];
                  }
                  return doses.map((m) {
                    final status =
                        (m['status'] ?? '').toString().toLowerCase();
                    final name = (m['medicationName'] ?? 'Med').toString();
                    final sched = (m['scheduledTime'] ?? '').toString();
                    final takenAt = _toDateTime(m['takenAt']);

                    String timeLabel = 'Scheduled $sched';
                    if (takenAt != null) {
                      timeLabel +=
                          ' • Taken ${DateFormat('hh:mm a').format(takenAt)}';
                    }

                    // tone per-card (onTime / late / missed)
                    final tone = status == 'missed'
                        ? DoseTone.missed
                        : (status == 'taken_late'
                            ? DoseTone.late
                            : DoseTone.onTime);

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
        },
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

    final today = DateTime.now();
    final todayKey =
        DateTime(today.year, today.month, today.day); // for comparison

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

            final bg = _bgForDay(dayNumber, monthData);
            final isToday = dayDate.year == todayKey.year &&
                dayDate.month == todayKey.month &&
                dayDate.day == todayKey.day;

            return _SummaryDayCell(
              day: dayNumber,
              bgColor: bg,          // may be null (transparent)
              selected: isSelected,
              isToday: isToday,     // blue border for today
              onTap: () => setState(() => _selectedDay = dayDate),
            );
          }),
        );
      }),
    );
  }
}

// ---------------- Small widgets ----------------

class _SummaryDow extends StatelessWidget {
  final String label;
  const _SummaryDow(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SummaryDayCell extends StatelessWidget {
  final int? day;
  final bool selected;
  final bool isToday;
  final Color? bgColor;      // circle color (nullable)
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

    // Medium size circle with clear colors
    final hasColor = bgColor != null;

    // Blue border for "today", primary for selected, else light grey
    final Color borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : (isToday
            ? Colors.blue // as requested
            : Colors.grey.shade300);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            width: 40,  // medium
            height: 40, // medium
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

// ===== New tone-based card =====
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
    // same layout; only the color changes per tone
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
        base = Colors.amber.shade700; // yellow variant
        icon = Icons.check_circle;    // same icon as onTime (as requested)
        trailingIcon = Icons.check;   // same trailing check
        break;
      case DoseTone.missed:
        base = Colors.red.shade700;
        icon = Icons.error;
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

// Legend (style #2): colored bullets + labels in a single row
class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
        fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: const [
        _LegendItem(color: Color(0xFFD32F2F), label: 'Missed'),    // red
        _LegendItem(color: Color(0xFFF9A825), label: 'Late'),      // yellow
        _LegendItem(color: Color(0xFF2E7D32), label: 'On time'),   // green
        _LegendItem(color: Color(0xFFEEEEEE), label: 'Upcoming'),  // light grey
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
    final style = TextStyle(
        fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w600);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}

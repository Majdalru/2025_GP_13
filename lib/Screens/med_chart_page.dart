import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MedChartPage extends StatefulWidget {
  final String elderlyId;
  final String medId;
  final String medName;
  final DateTime initialMonth;

  const MedChartPage({
    super.key,
    required this.elderlyId,
    required this.medId,
    required this.medName,
    required this.initialMonth,
  });

  @override
  State<MedChartPage> createState() => _MedChartPageState();
}

enum ChartViewMode { pie, bar, weekly }

class _MedChartPageState extends State<MedChartPage> {
  late DateTime _currentMonth; // نخزن أول يوم في الشهر
  ChartViewMode _chartMode = ChartViewMode.pie;

  @override
  void initState() {
    super.initState();
    _currentMonth =
        DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
  }

  int get _daysInMonth {
    final firstNext = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    return firstNext.subtract(const Duration(days: 1)).day;
  }

  void _goPrevMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _goNextMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

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

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _weekdayName(DateTime d) => DateFormat('EEEE').format(d);

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

  bool _looksLikeDose(Map v) {
    return v.containsKey('scheduledTime') ||
        v.containsKey('medicationName') ||
        v.containsKey('timeIndex') ||
        v.containsKey('status') ||
        v.containsKey('takenAt') ||
        v.containsKey('medicationId');
  }

  DateTime _medStartDate(Map<String, dynamic> med) {
    final raw = med['createdAt'];
    final dt = _toDateTime(raw);
    if (dt != null) return _dateOnly(dt);
    return _dateOnly(DateTime.now());
  }

  // =========== Streams ===========

  Stream<QuerySnapshot<Map<String, dynamic>>> _monthLogsStream() {
    final first = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final last =
        DateTime(_currentMonth.year, _currentMonth.month, _daysInMonth);
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

  Stream<DocumentSnapshot<Map<String, dynamic>>> _medsStream() {
    return FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.elderlyId)
        .snapshots();
  }

  // =========== منطق تجميع اللوقز ===========

  /// نفس اللي في MedsSummaryPage
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
            list.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // top-level maps + nested 'doses'
      data.forEach((k, v) {
        if (k == 'doses') return;
        if (v is Map<String, dynamic>) {
          if (_looksLikeDose(v)) {
            list.add(Map<String, dynamic>.from(v));
          }
          final nested = v['doses'];
          if (nested is List) {
            for (final it in nested) {
              if (it is Map<String, dynamic> && _looksLikeDose(it)) {
                list.add(Map<String, dynamic>.from(it));
              }
            }
          }
        }
      });

      res[doc.id] = list;
    }
    return res;
  }

  /// نفس _enrichWithSchedule في MedsSummaryPage
  Map<String, List<Map<String, dynamic>>> _enrichWithSchedule({
    required Map<String, List<Map<String, dynamic>>> monthLogs,
    required Map<String, dynamic>? medsDocData,
  }) {
    final res = <String, List<Map<String, dynamic>>>{};
    monthLogs.forEach((k, v) => res[k] = [...v]);

    if (medsDocData == null) return res;

    final medsList = medsDocData['medsList'];
    if (medsList is! List) return res;

    final todayOnly = _dateOnly(DateTime.now());

    for (int day = 1; day <= _daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dayOnly = _dateOnly(date);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final weekday = _weekdayName(date);

      final logsForDay = res[key] ?? <Map<String, dynamic>>[];

      // build indices
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

        final start = _medStartDate(med);
        if (dayOnly.isBefore(start)) continue;

        final end = _toDateTime(med['endDate']);
        if (end != null && dayOnly.isAfter(_dateOnly(end))) continue;
        if (med['archived'] == true) continue;

        final days = (med['days'] is List)
            ? (med['days'] as List).map((e) => e.toString()).toList()
            : <String>[];
        final runsToday = days.contains('Every day') || days.contains(weekday);
        if (!runsToday) continue;

        final timesRaw = med['times'];
        final times = <String>[];
        if (timesRaw is List) {
          for (final t in timesRaw) {
            if (t is String && t.contains(':')) {
              times.add(t);
            } else if (t is Map) {
              final hh = int.tryParse('${t['hour'] ?? t['h'] ?? t['HH'] ?? ''}');
              final mm = int.tryParse(
                  '${t['minute'] ?? t['m'] ?? t['MM'] ?? ''}');
              if (hh != null && mm != null) {
                times.add(
                    '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}');
              }
            }
          }
        }

        for (int i = 0; i < times.length; i++) {
          final sched = times[i];

          Map<String, dynamic>? log =
              (medId.isNotEmpty) ? byPair['$medId#$i'] : null;
          log ??= byTime[sched];
          if (log != null) continue;

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

  /// 🔹 dailyStats لهذا الدواء:
  /// { 'yyyy-MM-dd': {onTime, late, missed} }
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

  // ===================== HELP DIALOG =====================

  void _showChartHelp(BuildContext context, ChartViewMode mode) {
    String title;
    String body;

    switch (mode) {
      case ChartViewMode.pie:
        title = 'How to read this pie chart?';
        body =
            '• Each slice = group of doses this month\n'
            '• Green: doses taken on time\n'
            '• Yellow: doses taken late\n'
            '• Red: doses that were missed completely\n\n'
            'The size of each slice shows its percentage from ALL doses.';
        break;
      case ChartViewMode.bar:
        title = 'How to read this daily bar chart?';
        body =
            '• Each bar = one day of this month\n'
            '• Bar height = total number of doses that day\n'
            '• Green part = doses taken on time\n'
            '• Yellow part = doses taken late\n'
            '• Red part = missed doses\n\n'
            'This helps you see which days had more missed or late doses.';
        break;
      case ChartViewMode.weekly:
        title = 'How to read weekly trend?';
        body =
            '• Each card = one week in this month\n'
            '• It shows how many doses were on time, late, or missed\n'
            '• The percentage on the right is overall adherence for that week.\n\n'
            'Green weeks = very good adherence, red weeks = need attention.';
        break;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // ===================== BUILD =====================

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Summary • ${widget.medName}'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _monthLogsStream(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawMonthLogs = _collectMonthFromLogs(snap.data!);

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _medsStream(),
            builder: (context, medsSnap) {
              final medsData = medsSnap.data?.data();
              final monthData = _enrichWithSchedule(
                monthLogs: rawMonthLogs,
                medsDocData: medsData,
              );

              // إحصائيات هذا الدواء فقط
              final dailyStats =
                  _buildDailyStatsForMed(widget.medId, monthData);

              int onTime = 0;
              int late = 0;
              int missed = 0;
              dailyStats.values.forEach((m) {
                onTime += m['onTime'] ?? 0;
                late += m['late'] ?? 0;
                missed += m['missed'] ?? 0;
              });

              final total = onTime + late + missed;
              final monthlyStats = {
                'onTime': onTime,
                'late': late,
                'missed': missed,
              };
              final adherencePercent =
                  total == 0 ? 0.0 : ((onTime + late) / total) * 100.0;

              final monthName =
                  DateFormat('MMMM yyyy').format(_currentMonth);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildMonthHeader(monthName, cs),
                    const SizedBox(height: 12),
                    _buildModeToggle(cs),
                    const SizedBox(height: 16),
                    if (total == 0) ...[
                      Text(
                        'No doses for this month yet.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ] else ...[
                      _buildAdherenceCard(
                          cs, monthlyStats, total, adherencePercent),
                      const SizedBox(height: 24),
                      _buildSelectedChart(
                        context,
                        monthlyStats,
                        dailyStats,
                        adherencePercent,
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // =============== MONTH HEADER ===============

  Widget _buildMonthHeader(String monthName, ColorScheme cs) {
    return Row(
      children: [
        IconButton(
          onPressed: _goPrevMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
    );
  }

  // ====================== TOGGLE ======================

  Widget _buildModeToggle(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _ChartToggleButton(
            label: 'Status pie',
            selected: _chartMode == ChartViewMode.pie,
            onTap: () => setState(() => _chartMode = ChartViewMode.pie),
          ),
          _ChartToggleButton(
            label: 'Daily bar',
            selected: _chartMode == ChartViewMode.bar,
            onTap: () => setState(() => _chartMode = ChartViewMode.bar),
          ),
          _ChartToggleButton(
            label: 'Weekly trend',
            selected: _chartMode == ChartViewMode.weekly,
            onTap: () => setState(() => _chartMode = ChartViewMode.weekly),
          ),
        ],
      ),
    );
  }

  // ================= ADHERENCE CARD ===================

  Widget _buildAdherenceCard(
    ColorScheme cs,
    Map<String, int> monthlyStats,
    int total,
    double adherencePercent,
  ) {
    final onTime = monthlyStats['onTime'] ?? 0;
    final late = monthlyStats['late'] ?? 0;
    final missed = monthlyStats['missed'] ?? 0;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: adherencePercent / 100.0,
                    strokeWidth: 8,
                    backgroundColor: cs.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(
                      _adherenceColor(adherencePercent).withOpacity(0.65),
                    ),
                  ),
                  Text(
                    '${adherencePercent.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monthly adherence',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'On time: $onTime   •   Late: $late   •   Missed: $missed',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _adherenceMessage(total, adherencePercent),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // ================== SELECTED CHART ==================

  Widget _buildSelectedChart(
    BuildContext context,
    Map<String, int> monthlyStats,
    Map<String, Map<String, int>> dailyStats,
    double adherencePercent,
  ) {
    switch (_chartMode) {
      case ChartViewMode.pie:
        return _buildPieChart(context, monthlyStats);
      case ChartViewMode.bar:
        return _buildBarChart(context, dailyStats);
      case ChartViewMode.weekly:
        return _buildWeeklyTrend(context, dailyStats);
    }
  }

  // ====================== PIE CHART ===================

  Widget _buildPieChart(BuildContext context, Map<String, int> monthlyStats) {
    final onTime = monthlyStats['onTime'] ?? 0;
    final late = monthlyStats['late'] ?? 0;
    final missed = monthlyStats['missed'] ?? 0;
    final total = (onTime + late + missed).toDouble();

    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Dose status (this month)',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: cs.primary,
                ),
                tooltip: 'How to understand this chart?',
                onPressed: () => _showChartHelp(context, ChartViewMode.pie),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  startDegreeOffset: -90,
                  sections: _buildPieSections(onTime, late, missed),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (total > 0)
          Text(
            'On time: $onTime (${(onTime / total * 100).toStringAsFixed(0)}%)   •   '
            'Late: $late (${(late / total * 100).toStringAsFixed(0)}%)   •   '
            'Missed: $missed (${(missed / total * 100).toStringAsFixed(0)}%)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        const SizedBox(height: 12),
        _buildPieLegend(),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections(int onTime, int late, int missed) {
    final total = (onTime + late + missed).toDouble();
    if (total == 0) return [];

    const double radius = 60;

    final sections = <PieChartSectionData>[];

    if (onTime > 0) {
      sections.add(
        PieChartSectionData(
          value: onTime.toDouble(),
          title: '${(onTime / total * 100).toStringAsFixed(0)}%',
          color: const Color(0xFF2E7D32),
          radius: radius,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }
    if (late > 0) {
      sections.add(
        PieChartSectionData(
          value: late.toDouble(),
          title: '${(late / total * 100).toStringAsFixed(0)}%',
          color: const Color(0xFFF9A825),
          radius: radius,
          titleStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }
    if (missed > 0) {
      sections.add(
        PieChartSectionData(
          value: missed.toDouble(),
          title: '${(missed / total * 100).toStringAsFixed(0)}%',
          color: const Color(0xFFD32F2F),
          radius: radius,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      );
    }

    return sections;
  }

  Widget _buildPieLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: const [
        _ChartLegendItem(
          color: Color(0xFF2E7D32),
          label: 'On time',
        ),
        _ChartLegendItem(
          color: Color(0xFFF9A825),
          label: 'Late',
        ),
        _ChartLegendItem(
          color: Color(0xFFD32F2F),
          label: 'Missed',
        ),
      ],
    );
  }

  // ====================== BAR CHART ===================

  Widget _buildBarChart(
    BuildContext context,
    Map<String, Map<String, int>> dailyStats,
  ) {
    final days = _buildDayList(dailyStats);
    if (days.isEmpty) {
      return const Text('No daily data available for this month.');
    }

    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Daily doses by status (stacked bar)',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints.tightFor(
                  width: 32,
                  height: 32,
                ),
                icon: Icon(
                  Icons.help_outline,
                  size: 18,
                  color: cs.primary,
                ),
                tooltip: 'How to understand this chart?',
                onPressed: () => _showChartHelp(context, ChartViewMode.bar),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: BarChart(_buildBarChartData(days)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: const [
            _ChartLegendItem(
              color: Color(0xFF2E7D32),
              label: 'On time',
            ),
            _ChartLegendItem(
              color: Color(0xFFF9A825),
              label: 'Late',
            ),
            _ChartLegendItem(
              color: Color(0xFFD32F2F),
              label: 'Missed',
            ),
          ],
        ),
      ],
    );
  }

  List<_DayStat> _buildDayList(Map<String, Map<String, int>> dailyStats) {
    final entries = dailyStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries.map((entry) {
      final dt = DateTime.parse(entry.key);
      final m = entry.value;

      final int onTime = m['onTime'] ?? 0;
      final int late = m['late'] ?? 0;
      final int missed = m['missed'] ?? 0;
      final int total = onTime + late + missed;

      final double adherence =
          total == 0 ? 0.0 : ((onTime + late) / total * 100.0);

      return _DayStat(
        date: dt,
        onTime: onTime,
        late: late,
        missed: missed,
        total: total,
        adherence: adherence,
      );
    }).toList();
  }

  BarChartData _buildBarChartData(List<_DayStat> days) {
    if (days.isEmpty) {
      return BarChartData(barGroups: []);
    }

    final int maxTotal =
        days.map((d) => d.total).fold<int>(0, (a, b) => a > b ? a : b);

    final daysLocal = days;

    return BarChartData(
      maxY: (maxTotal == 0 ? 1 : maxTotal).toDouble(),
      barGroups: List.generate(daysLocal.length, (i) {
        final d = daysLocal[i];
        final double total = d.total.toDouble();
        double current = 0;

        final List<BarChartRodStackItem> stacks = [];

        if (d.onTime > 0) {
          stacks.add(
            BarChartRodStackItem(
              current,
              current + d.onTime.toDouble(),
              const Color(0xFF2E7D32),
            ),
          );
          current += d.onTime.toDouble();
        }
        if (d.late > 0) {
          stacks.add(
            BarChartRodStackItem(
              current,
              current + d.late.toDouble(),
              const Color(0xFFF9A825),
            ),
          );
          current += d.late.toDouble();
        }
        if (d.missed > 0) {
          stacks.add(
            BarChartRodStackItem(
              current,
              current + d.missed.toDouble(),
              const Color(0xFFD32F2F),
            ),
          );
          current += d.missed.toDouble();
        }

        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total,
              width: 14,
              borderRadius: BorderRadius.circular(4),
              rodStackItems: stacks,
            ),
          ],
        );
      }),
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final d = daysLocal[group.x.toInt()];
            return BarTooltipItem(
              'Day ${d.date.day}\n'
              'On time: ${d.onTime}\n'
              'Late: ${d.late}\n'
              'Missed: ${d.missed}',
              const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Text(
              'Number of doses',
              style: TextStyle(fontSize: 11),
            ),
          ),
          axisNameSize: 18,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: 1,
            getTitlesWidget: (value, meta) => Text(
              value.toInt().toString(),
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Day of month',
              style: TextStyle(fontSize: 11),
            ),
          ),
          axisNameSize: 18,
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= daysLocal.length) {
                return const SizedBox.shrink();
              }
              final d = daysLocal[i];
              return Text(
                '${d.date.day}',
                style: const TextStyle(fontSize: 10),
              );
            },
          ),
        ),
      ),
      gridData: FlGridData(show: true, horizontalInterval: 1),
      borderData: FlBorderData(show: false),
    );
  }

  // ==================== WEEKLY TREND =================

  Widget _buildWeeklyTrend(
    BuildContext context,
    Map<String, Map<String, int>> dailyStats,
  ) {
    final days = _buildDayList(dailyStats);

    if (days.isEmpty) {
      return const Text('No data available for weekly trend.');
    }

    final Map<int, List<_DayStat>> weeklyMap = {
      1: [],
      2: [],
      3: [],
      4: [],
      5: [],
    };

    for (final d in days) {
      final dayNum = d.date.day;
      int week = ((dayNum - 1) ~/ 7) + 1;
      if (week > 5) week = 5;
      weeklyMap[week]!.add(d);
    }

    final weeklyStats = <_WeeklyStat>[];

    weeklyMap.forEach((week, list) {
      if (list.isEmpty) return;

      int onTime = 0;
      int late = 0;
      int missed = 0;

      for (final d in list) {
        onTime += d.onTime;
        late += d.late;
        missed += d.missed;
      }

      final total = onTime + late + missed;
      final double adherence =
          total == 0 ? 0.0 : ((onTime + late) / total * 100.0);

      final startDay =
          list.map((d) => d.date.day).reduce((a, b) => a < b ? a : b);
      final endDay =
          list.map((d) => d.date.day).reduce((a, b) => a > b ? a : b);

      weeklyStats.add(
        _WeeklyStat(
          week: week,
          onTime: onTime,
          late: late,
          missed: missed,
          adherence: adherence,
          startDay: startDay,
          endDay: endDay,
        ),
      );
    });

    if (weeklyStats.isEmpty) {
      return const Text('Not enough data for weekly trend.');
    }

    weeklyStats.sort((a, b) => a.week.compareTo(b.week));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Weekly adherence trend',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...weeklyStats.map((w) {
          final Color color = w.adherence >= 80
              ? const Color(0xFF2E7D32)
              : w.adherence >= 50
                  ? const Color(0xFFF9A825)
                  : const Color(0xFFD32F2F);

          return Card(
            color: color.withOpacity(.08),
            child: ListTile(
              title: Text(
                'Week ${w.week}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.startDay == w.endDay
                        ? 'Day: ${w.startDay}'
                        : 'Days: ${w.startDay}–${w.endDay}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'On time: ${w.onTime}   •   Late: ${w.late}   •   Missed: ${w.missed}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              trailing: Text(
                '${w.adherence.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ================ Helper getters ===================

  Color _adherenceColor(double pct) {
    if (pct >= 80) return const Color(0xFF2E7D32);
    if (pct >= 50) return const Color(0xFFF9A825);
    return const Color(0xFFD32F2F);
  }

  String _adherenceMessage(int total, double pct) {
    if (total == 0) return 'No data yet for this month.';
    if (pct >= 80) {
      return 'Great adherence 👏';
    } else if (pct >= 50) {
      return 'Moderate adherence – can be improved 🙂';
    } else {
      return 'Low adherence – needs attention ⚠️';
    }
  }
}

// ================= Helper classes & widgets =============

class _DayStat {
  final DateTime date;
  final int onTime;
  final int late;
  final int missed;
  final int total;
  final double adherence;

  _DayStat({
    required this.date,
    required this.onTime,
    required this.late,
    required this.missed,
    required this.total,
    required this.adherence,
  });
}

class _WeeklyStat {
  final int week;
  final int onTime;
  final int late;
  final int missed;
  final double adherence;
  final int startDay;
  final int endDay;

  _WeeklyStat({
    required this.week,
    required this.onTime,
    required this.late,
    required this.missed,
    required this.adherence,
    required this.startDay,
    required this.endDay,
  });
}

class _ChartToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChartToggleButton({
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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
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

class _ChartLegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendItem({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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

// lib/Screens/med_chart_page.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MedChartPage extends StatefulWidget {
  /// اسم الدواء
  final String medName;

  /// إحصائيات شهرية إجمالية للدواء الواحد: { "onTime": x, "late": y, "missed": z }
  final Map<String, int> monthlyStats;

  /// إحصائيات يومية للدواء الواحد:
  /// key: "yyyy-MM-dd"
  /// value: { "onTime": x, "late": y, "missed": z }
  final Map<String, Map<String, int>> dailyStats;

  const MedChartPage({
    super.key,
    required this.medName,
    required this.monthlyStats,
    required this.dailyStats,
  });

  @override
  State<MedChartPage> createState() => _MedChartPageState();
}

enum ChartViewMode { pie, bar, weekly }

class _MedChartPageState extends State<MedChartPage> {
  late final int _onTime;
  late final int _late;
  late final int _missed;
  late final int _total;
  late final double _adherencePercent;

  ChartViewMode _chartMode = ChartViewMode.pie;

  /// نحول dailyStats إلى List مرتبة حسب التاريخ
  List<_DayStat> get _dayList {
    final entries = widget.dailyStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries.map((entry) {
      final dt = DateTime.parse(entry.key);
      final m = entry.value;

      final int onTime = m['onTime'] ?? 0;
      final int late   = m['late'] ?? 0;
      final int missed = m['missed'] ?? 0;
      final int total  = onTime + late + missed;

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

  @override
  void initState() {
    super.initState();

    _onTime = widget.monthlyStats['onTime'] ?? 0;
    _late   = widget.monthlyStats['late'] ?? 0;
    _missed = widget.monthlyStats['missed'] ?? 0;
    _total  = _onTime + _late + _missed;

    _adherencePercent =
        _total == 0 ? 0.0 : ((_onTime + _late) / _total) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_total == 0) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Summary • ${widget.medName}'),
        ),
        body: const Center(
          child: Text('No doses for this month yet'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Summary • ${widget.medName}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildModeToggle(cs),
            const SizedBox(height: 16),
            _buildAdherenceCard(cs),
            const SizedBox(height: 24),
            _buildSelectedChart(context),
          ],
        ),
      ),
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

  Widget _buildAdherenceCard(ColorScheme cs) {
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
                    value: _adherencePercent / 100.0,
                    strokeWidth: 8,
                    backgroundColor: cs.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation(_adherenceColor),
                  ),
                  Text(
                    '${_adherencePercent.toStringAsFixed(0)}%',
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
                    'On time: $_onTime   •   Late: $_late   •   Missed: $_missed',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _adherenceMessage,
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

  Widget _buildSelectedChart(BuildContext context) {
    switch (_chartMode) {
      case ChartViewMode.pie:
        return _buildPieChart(context);
      case ChartViewMode.bar:
        return _buildBarChart(context);
      case ChartViewMode.weekly:
        return _buildWeeklyTrend(context);
    }
  }

  // ====================== PIE CHART ===================

  Widget _buildPieChart(BuildContext context) {
    final total = _total.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dose status (this month)',
          style: Theme.of(context).textTheme.titleMedium,
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
                  sections: _buildPieSections(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Each slice shows percentage of all doses this month.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 12),
        Text(
          'On time: $_onTime (${(_onTime / total * 100).toStringAsFixed(0)}%)   •   '
          'Late: $_late (${(_late / total * 100).toStringAsFixed(0)}%)   •   '
          'Missed: $_missed (${(_missed / total * 100).toStringAsFixed(0)}%)',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),

        _buildPieLegend(),
      ],
    );
  }

  List<PieChartSectionData> _buildPieSections() {
    final total = _total.toDouble();
    if (total == 0) return [];

    const double radius = 60; // نفس الحجم لكل القطع

    final sections = <PieChartSectionData>[];

    if (_onTime > 0) {
      sections.add(
        PieChartSectionData(
          value: _onTime.toDouble(),
          title: '${(_onTime / total * 100).toStringAsFixed(0)}%',
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
    if (_late > 0) {
      sections.add(
        PieChartSectionData(
          value: _late.toDouble(),
          title: '${(_late / total * 100).toStringAsFixed(0)}%',
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
    if (_missed > 0) {
      sections.add(
        PieChartSectionData(
          value: _missed.toDouble(),
          title: '${(_missed / total * 100).toStringAsFixed(0)}%',
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

  Widget _buildBarChart(BuildContext context) {
    final days = _dayList;
    if (days.isEmpty) {
      return const Text('No daily data available for this month.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Daily doses by status (stacked bar)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 1,
          child: SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: BarChart(_buildBarChartData()),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Each bar = 1 day. Height = number of doses. Colors = status.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
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

  BarChartData _buildBarChartData() {
    final days = _dayList;
    if (days.isEmpty) {
      return BarChartData(barGroups: []);
    }

    final int maxTotal =
        days.map((d) => d.total).fold<int>(0, (a, b) => a > b ? a : b);

    return BarChartData(
      maxY: (maxTotal == 0 ? 1 : maxTotal).toDouble(),
      barGroups: List.generate(days.length, (i) {
        final d = days[i];
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
            final d = _dayList[group.x.toInt()];
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
              final days = _dayList;
              if (i < 0 || i >= days.length) {
                return const SizedBox.shrink();
              }
              final d = days[i];
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

  Widget _buildWeeklyTrend(BuildContext context) {
    final days = _dayList;

    if (days.isEmpty) {
      return const Text('No data available for weekly trend.');
    }

    // تقسيم الأيام على أسابيع (1–7, 8–14, 15–21, 22–28, 29–31)
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
      int late   = 0;
      int missed = 0;

      for (final d in list) {
        onTime += d.onTime;
        late   += d.late;
        missed += d.missed;
      }

      final total = onTime + late + missed;
      final double adherence =
          total == 0 ? 0.0 : ((onTime + late) / total * 100.0);

      // أقل وأعلى يوم داخل هذا الأسبوع
      final startDay = list
          .map((d) => d.date.day)
          .reduce((a, b) => a < b ? a : b);
      final endDay = list
          .map((d) => d.date.day)
          .reduce((a, b) => a > b ? a : b);

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

  Color get _adherenceColor {
    if (_adherencePercent >= 80) return const Color(0xFF2E7D32);
    if (_adherencePercent >= 50) return const Color(0xFFF9A825);
    return const Color(0xFFD32F2F);
  }

  String get _adherenceMessage {
    if (_total == 0) return 'No data yet for this month.';
    if (_adherencePercent >= 80) {
      return 'Great adherence 👏';
    } else if (_adherencePercent >= 50) {
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MedsSummaryPage extends StatefulWidget {
  const MedsSummaryPage({super.key});

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

  int get _weekdayOfFirst {
    return DateTime(_current.year, _current.month, 1).weekday;
  }

  void _goPrevMonth() {
    setState(() {
      _current = DateTime(_current.year, _current.month - 1, 1);
      _selectedDay = null;
    });
  }

  void _goNextMonth() {
    setState(() {
      _current = DateTime(_current.year, _current.month + 1, 1);
      _selectedDay = null;
    });
  }

  // الألوان حسب حالة اليوم
  Color? _dotForDay(int day) {
    final DateTime today = DateTime.now();
    final DateTime dayDate = DateTime(_current.year, _current.month, day);

    // الأيام القادمة → بدون لون
    if (dayDate.isAfter(DateTime(today.year, today.month, today.day))) {
      return Colors.grey.shade200; // رمادي فاتح جدًا (محايد)
    }

    // الأيام الماضية أو اليوم نفسه → فيها ألوان حسب الحالة
    if (day % 5 == 2) return Colors.red; // سيء
    if (day % 3 == 0) return Colors.orange; // متوسط
    return Colors.green; // جيد
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy').format(_current);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // شريط اختيار الشهر
          Row(
            children: [
              IconButton(onPressed: _goPrevMonth, icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
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
              IconButton(onPressed: _goNextMonth, icon: const Icon(Icons.chevron_right)),
            ],
          ),
          const SizedBox(height: 8),

          // عناوين أيام الأسبوع
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _Dow('Mon'), _Dow('Tue'), _Dow('Wed'), _Dow('Thu'),
              _Dow('Fri'), _Dow('Sat'), _Dow('Sun'),
            ],
          ),
          const SizedBox(height: 8),

          // شبكة التقويم
          _buildCalendarGrid(context),

          const SizedBox(height: 16),

          // تفاصيل اليوم المحدد
          if (_selectedDay != null) ...[
            Text(
              DateFormat('d MMMM').format(_selectedDay!),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const _MedStatusRow(name: 'Med name', time: '8:00 AM', ok: true),
            const _MedStatusRow(name: 'Med name', time: '1:00 PM', ok: true),
            const _MedStatusRow(name: 'Med name', time: '8:00 PM', ok: false),
          ] else
            const Text('Select a day to view details'),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final leadingEmpty = (_weekdayOfFirst + 6) % 7;
    final totalCells = leadingEmpty + _daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (col) {
            final cellIndex = row * 7 + col;
            final dayNumber = cellIndex - leadingEmpty + 1;

            if (dayNumber < 1 || dayNumber > _daysInMonth) {
              return const _DayCell.empty();
            }

            final dayDate = DateTime(_current.year, _current.month, dayNumber);
            final isSelected = _selectedDay != null &&
                dayDate.year == _selectedDay!.year &&
                dayDate.month == _selectedDay!.month &&
                dayDate.day == _selectedDay!.day;

            return _DayCell(
              day: dayNumber,
              dotColor: _dotForDay(dayNumber),
              selected: isSelected,
              onTap: () => setState(() => _selectedDay = dayDate),
            );
          }),
        );
      }),
    );
  }
}

class _Dow extends StatelessWidget {
  final String label;
  const _Dow(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int? day;
  final bool selected;
  final Color? dotColor;
  final VoidCallback? onTap;

  const _DayCell({
    this.day,
    this.selected = false,
    this.dotColor,
    this.onTap,
    super.key,
  });

  const _DayCell.empty({super.key})
      : day = null, selected = false, dotColor = null, onTap = null;

  @override
  Widget build(BuildContext context) {
    if (day == null) return const Expanded(child: SizedBox(height: 52));

    final Color bg = dotColor ?? Colors.transparent;
    final textColor = bg == Colors.transparent
        ? Colors.grey.shade400 // الأيام الجاية رمادية باهتة
        : Colors.white;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade300;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bg == Colors.transparent ? null : bg.withOpacity(.85),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
              boxShadow: selected
                  ? [BoxShadow(color: borderColor.withOpacity(.25), blurRadius: 8)]
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedStatusRow extends StatelessWidget {
  final String name, time;
  final bool ok;

  const _MedStatusRow({required this.name, required this.time, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green.shade600 : Colors.red.shade700;
    return Card(
      color: color.withOpacity(.08),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(ok ? Icons.check_circle : Icons.error, color: color),
        ),
        title: Text(name, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        subtitle: Text(time),
        trailing: Icon(ok ? Icons.check : Icons.close, color: color),
      ),
    );
  }
}

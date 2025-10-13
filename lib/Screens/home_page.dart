import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String elderlyName;
  final VoidCallback onTapArrowToMedsSummary;
  final VoidCallback onTapEmergency;

  const HomePage({
    super.key,
    required this.elderlyName,
    required this.onTapArrowToMedsSummary,
    required this.onTapEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ===== Emergency alert (مودرن + Gradient) =====
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

        // ===== Today Card =====
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    // اسم اليوم/التاريخ
                    Text(
                      'Today • 7 OCT',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    // السهم للـ Summary
                    IconButton.filledTonal(
                      tooltip: 'Go to Summary',
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primary.withOpacity(.10),
                      ),
                      onPressed: onTapArrowToMedsSummary,
                      icon: Icon(Icons.play_arrow_rounded, color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Divider(color: Colors.grey.withOpacity(.25), height: 20),

                // صفوف الأدوية (مثال)
                const _MedTodayRow(
                  name: 'Med name',
                  time: '8:00 AM',
                  done: true,
                ),
                const _MedTodayRow(
                  name: 'Med name',
                  time: '1:00 PM',
                  done: true,
                ),
                const _MedTodayRow(
                  name: 'Med name',
                  time: '8:00 PM',
                  done: false,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ملاحظة خفيفة (اختياري)
        Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              'You are viewing ${elderlyName} daily meds.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ],
    );
  }
}

class _MedTodayRow extends StatelessWidget {
  final String name;
  final String time;
  final bool done;

  const _MedTodayRow({
    required this.name,
    required this.time,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = done ? Colors.green : Colors.orange;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.medication_outlined, color: accent),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(time),
        trailing: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: accent,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

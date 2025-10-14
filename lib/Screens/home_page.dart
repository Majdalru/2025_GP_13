import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/medmain.dart'; // 👈 1. Import Medmain page
import 'meds_summary_page.dart'; // 👈 2. Import Summary page
import 'location_page.dart'; // Add this import for date formatting

// You can either copy these models here or import them from your medmain.dart file
enum MedStatus { taken, late, missed }

class TodaysMedication {
  final String name;
  final TimeOfDay time;
  final MedStatus? status; // Null for upcoming meds

  TodaysMedication({required this.name, required this.time, this.status});
}
// End of models

class HomePage extends StatelessWidget {
  final String elderlyName;
  // This is for the NEW 'Monthly Overview' link
  final VoidCallback onTapArrowToMedsSummary;
  // This is the NEW callback for the arrow icon to go to Medmain()
  final VoidCallback onTapArrowToMedmain;
  final VoidCallback onTapEmergency;

  const HomePage({
    super.key,
    required this.elderlyName,
    required this.onTapArrowToMedsSummary,
    required this.onTapArrowToMedmain, // Added for the arrow icon
    required this.onTapEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final formattedDate = DateFormat('d MMM').format(now).toUpperCase();

    // --- Placeholder Data ---
    // In a real app, this data would come from a database or state management
    final TodaysMedication nextMed = TodaysMedication(
      name: 'Aspirin',
      time: const TimeOfDay(hour: 18, minute: 0),
    );

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
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              4,
            ), // Adjusted padding
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      'Today • $formattedDate', // Dynamic Date
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Go to Medications', // Tooltip updated
                      style: IconButton.styleFrom(
                        backgroundColor: cs.primary.withOpacity(.10),
                      ),
                      // ***** CHANGE 1: Point to the new Medmain() callback *****
                      onPressed: onTapArrowToMedmain,
                      icon: Icon(Icons.play_arrow_rounded, color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Divider(color: Colors.grey.withOpacity(.25), height: 20),
                const SizedBox(height: 12),

                // --- NEW BRIEF WIDGETS ---
                _NextMedicationCard(med: nextMed),
                const SizedBox(height: 16),
                _MedicationStatusSummary(historyMeds: historyMeds),
                const SizedBox(height: 12),

                // ***** CHANGE 2: Added Monthly Overview Link *****
                Divider(color: Colors.grey.withOpacity(.25), height: 1),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed:
                        onTapArrowToMedsSummary, // This now goes to the summary
                    child: const Text(
                      'Monthly Overview',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
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
              'You are viewing ${elderlyName} daily meds.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ],
    );
  }
}

// --- NEW WIDGET: Brief card for the next upcoming medication ---
class _NextMedicationCard extends StatelessWidget {
  final TodaysMedication med;
  const _NextMedicationCard({required this.med});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.upcoming_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Next Up", style: TextStyle(color: Colors.grey)),
                Text(
                  med.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            med.time.format(context),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// --- NEW WIDGET: Brief summary of medication history ---
class _MedicationStatusSummary extends StatelessWidget {
  final List<TodaysMedication> historyMeds;
  const _MedicationStatusSummary({required this.historyMeds});

  @override
  Widget build(BuildContext context) {
    // Calculate counts for each status
    final takenCount = historyMeds
        .where((m) => m.status == MedStatus.taken)
        .length;
    final lateCount = historyMeds
        .where((m) => m.status == MedStatus.late)
        .length;
    final missedCount = historyMeds
        .where((m) => m.status == MedStatus.missed)
        .length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _StatusItem(
          count: takenCount,
          label: 'Taken',
          color: Colors.green.shade700,
          icon: Icons.check_circle_outline,
        ),
        _StatusItem(
          count: lateCount,
          label: 'Late',
          color: Colors.orange.shade800,
          icon: Icons.warning_amber_rounded,
        ),
        _StatusItem(
          count: missedCount,
          label: 'Missed',
          color: Colors.red.shade700,
          icon: Icons.cancel_outlined,
        ),
      ],
    );
  }
}

// --- Helper widget for each item in the status summary ---
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

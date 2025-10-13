import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ===== Custom Color Palette =====
// Kept for theming non-status UI elements for a professional look.
const Color kDarkSlateBlue = Color(0xFF2A4D69);
const Color kMutedGold = Color(0xFFF4D06F);
const Color kTealBlue = Color(0xFF5B9B9C);
const Color kLightAqua = Color(0xFF9DD9D2);

// Models
enum MedStatus { taken, late, missed }

class TodaysMedication {
  final String name;
  final TimeOfDay time;
  final MedStatus? status;

  TodaysMedication({required this.name, required this.time, this.status});
}
// End of models

class HomePage extends StatelessWidget {
  final String elderlyName;
  // UPDATED: Renamed for clarity to reflect its new destination
  final VoidCallback onTapArrowToMedMain;
  // NEW: Callback for the new monthly overview button
  final VoidCallback onTapMonthlyOverview;
  final VoidCallback onTapEmergency;

  const HomePage({
    super.key,
    required this.elderlyName,
    required this.onTapArrowToMedMain,
    required this.onTapMonthlyOverview,
    required this.onTapEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final formattedDate = DateFormat('d MMM').format(now).toUpperCase();

    // --- Placeholder Data ---
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
        // ===== Emergency Alert (REVERTED to RED) =====
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

        // ===== Today Card (Styled with New Palette) =====
        Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
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
                    Text(
                      'Today • $formattedDate',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: kDarkSlateBlue, // Using new palette color
                      ),
                    ),
                    const Spacer(),
                    IconButton.filledTonal(
                      tooltip: 'Go to Med Main Page', // UPDATED tooltip
                      style: IconButton.styleFrom(
                        backgroundColor: kDarkSlateBlue.withOpacity(.10),
                      ),
                      // UPDATED: This now navigates to the med main page
                      onPressed: onTapArrowToMedMain,
                      icon: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: kDarkSlateBlue,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Divider(color: Colors.grey.withOpacity(.25), height: 20),
                const SizedBox(height: 12),
                _NextMedicationCard(med: nextMed),
                const SizedBox(height: 16),
                _MedicationStatusSummary(historyMeds: historyMeds),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: kDarkSlateBlue.withOpacity(0.8),
            ),
            const SizedBox(width: 6),
            Text(
              'You are viewing ${elderlyName} daily meds.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // ===== NEW Monthly Overview Button =====
        Center(
          child: OutlinedButton.icon(
            onPressed: onTapMonthlyOverview,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Monthly Overview'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kDarkSlateBlue,
              side: BorderSide(color: kDarkSlateBlue.withOpacity(0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Card for next medication (Styled with New Palette) ---
class _NextMedicationCard extends StatelessWidget {
  final TodaysMedication med;
  const _NextMedicationCard({required this.med});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kDarkSlateBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDarkSlateBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.upcoming_outlined, color: kDarkSlateBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Next Up", style: TextStyle(color: kDarkSlateBlue)),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: kDarkSlateBlue,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Summary of medication history (REVERTED to OG Colors) ---
class _MedicationStatusSummary extends StatelessWidget {
  final List<TodaysMedication> historyMeds;
  const _MedicationStatusSummary({required this.historyMeds});

  @override
  Widget build(BuildContext context) {
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
          color: Colors.green.shade700, // Reverted
          icon: Icons.check_circle_outline,
        ),
        _StatusItem(
          count: lateCount,
          label: 'Late',
          color: Colors.orange.shade800, // Reverted
          icon: Icons.warning_amber_rounded,
        ),
        _StatusItem(
          count: missedCount,
          label: 'Missed',
          color: Colors.red.shade700, // Reverted
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/medication.dart'; // Make sure DoseStatus is defined here
import '../services/medication_scheduler.dart';
import 'package:collection/collection.dart'; // For firstWhereOrNull

// Combined data class for display
class MedicationDose {
  final Medication medication;
  final TimeOfDay scheduledTime;
  final int timeIndex; // Original index from Medication.times
  DoseStatus status;
  Timestamp? takenAt;

  MedicationDose({
    required this.medication,
    required this.scheduledTime,
    required this.timeIndex,
    this.status = DoseStatus.upcoming,
    this.takenAt,
  });

  // Helper to get the full DateTime for today
  DateTime get scheduledDateTime {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      scheduledTime.hour,
      scheduledTime.minute,
    );
  }

  // Key for storing/retrieving status in Firestore log
  String get logKey => '${medication.id}_$timeIndex';
}

class TodaysMedsTab extends StatefulWidget {
  final String elderlyId;
  final bool isCaregiverView; // Flag to differentiate UI

  const TodaysMedsTab({
    super.key,
    required this.elderlyId,
    this.isCaregiverView = false, // Default to elderly view
  });

  @override
  State<TodaysMedsTab> createState() => _TodaysMedsTabState();
}

class _TodaysMedsTabState extends State<TodaysMedsTab> {
  final MedicationScheduler _scheduler = MedicationScheduler();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<MedicationDose>> _getTodaysDosesStream() {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final todayName = DateFormat('EEEE').format(now); // e.g., 'Monday'

    final medsStream = _firestore
        .collection('medications')
        .doc(widget.elderlyId)
        .snapshots();

    return medsStream.asyncMap((medsSnapshot) async {
      final List<Medication> scheduledMeds = [];
      if (medsSnapshot.exists && medsSnapshot.data()?['medsList'] != null) {
        final allMeds = (medsSnapshot.data()!['medsList'] as List)
            .map((m) => Medication.fromMap(m as Map<String, dynamic>))
            .toList();
        scheduledMeds.addAll(
          allMeds.where(
            (med) =>
                med.days.contains('Every day') || med.days.contains(todayName),
          ),
        );
      }

      if (scheduledMeds.isEmpty) {
        return <MedicationDose>[];
      }

      DocumentSnapshot<Map<String, dynamic>> logDoc;
      Map<String, dynamic> logData = {};
      try {
        logDoc = await _firestore
            .collection('medication_log')
            .doc(widget.elderlyId)
            .collection('daily_log')
            .doc(todayKey)
            .get();
        if (logDoc.exists) {
          logData = logDoc.data() ?? {};
        }
      } catch (e) {
        debugPrint("Error fetching log document for $todayKey: $e");
      }

      final doses = <MedicationDose>[];
      final currentTime = DateTime.now();

      for (final med in scheduledMeds) {
        for (int i = 0; i < med.times.length; i++) {
          final time = med.times[i];
          final dose = MedicationDose(
            medication: med,
            scheduledTime: time,
            timeIndex: i,
          );

          final scheduledDT = dose.scheduledDateTime;
          final missedThresholdTime = scheduledDT.add(
            const Duration(minutes: 10),
          );

          final doseLog = logData[dose.logKey] as Map<String, dynamic>?;
          if (doseLog != null) {
            dose.status = _parseDoseStatus(doseLog['status'] as String?);
            dose.takenAt = doseLog['takenAt'] as Timestamp?;
          } else {
            // If no log, determine if missed or upcoming based on current time
            if (currentTime.isAfter(missedThresholdTime)) {
              dose.status = DoseStatus.missed;
            } else {
              dose.status =
                  DoseStatus.upcoming; // Includes past due within grace period
            }
          }
          doses.add(dose);
        }
      }

      // Sort all doses initially by scheduled time
      doses.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));
      return doses;
    });
  }

  // --- Helper Functions (_parseDoseStatus, _statusToString, _markAsTaken, _undoTaken) remain the same ---
  DoseStatus _parseDoseStatus(String? statusString) {
    switch (statusString) {
      case 'taken_on_time':
        return DoseStatus.takenOnTime;
      case 'taken_late':
        return DoseStatus.takenLate;
      case 'missed':
        return DoseStatus.missed;
      case 'upcoming': // Keep upcoming from log if explicitly set?
        return DoseStatus.upcoming;
      default:
        return DoseStatus.upcoming; // Default if null or unexpected
    }
  }

  String _statusToString(DoseStatus status) {
    switch (status) {
      case DoseStatus.takenOnTime:
        return 'taken_on_time';
      case DoseStatus.takenLate:
        return 'taken_late';
      case DoseStatus.missed:
        return 'missed';
      case DoseStatus.upcoming:
        return 'upcoming'; // Explicitly store upcoming if needed?
    }
  }

  Future<void> _markAsTaken(MedicationDose dose) async {
    final now = DateTime.now();
    final scheduledDT = dose.scheduledDateTime;
    final logKey = dose.logKey;
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    DoseStatus newStatus;
    // Mark as late if current time is after scheduled time + 1 sec (to avoid edge cases exactly on time)
    if (now.isAfter(scheduledDT.add(const Duration(seconds: 360)))) {
      newStatus = DoseStatus.takenLate;
    } else {
      newStatus = DoseStatus.takenOnTime;
    }

    final logUpdate = {
      logKey: {
        'status': _statusToString(newStatus),
        'takenAt': Timestamp.now(),
        'medicationName': dose.medication.name,
        'scheduledTime': DateFormat('HH:mm').format(scheduledDT),
        'medicationId': dose.medication.id,
        'timeIndex': dose.timeIndex,
      },
    };

    try {
      await _firestore
          .collection('medication_log')
          .doc(widget.elderlyId)
          .collection('daily_log')
          .doc(todayKey)
          .set(logUpdate, SetOptions(merge: true));

      debugPrint(
        "Firestore log updated for ${dose.logKey} to ${newStatus.name}",
      );

    await _scheduler.markMedicationTaken(
  widget.elderlyId,
  dose.medication.id,
  dose.timeIndex,
  scheduledDT, // ✅ أضيفي هذا السطر
);

      // Pass scheduledDT to notification functions
      if (newStatus == DoseStatus.takenLate) {
        await _scheduler.notifyCaregiversTakenLate(
          elderlyId: widget.elderlyId,
          medication: dose.medication,
          takenAt: now,
          scheduledTime: scheduledDT, // Pass scheduled time
        );
      } else {
        // Notify on time if needed
        await _scheduler.notifyCaregiversTakenOnTime(
          elderlyId: widget.elderlyId,
          medication: dose.medication,
          takenAt: now,
          scheduledTime: scheduledDT, // Pass scheduled time
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  newStatus == DoseStatus.takenOnTime 
                      ? Icons.check_circle 
                      : Icons.access_time,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  '${dose.medication.name}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  newStatus == DoseStatus.takenOnTime 
                      ? 'The medication was taken on time ✓' 
                      : 'The medication was taken late',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            backgroundColor: newStatus == DoseStatus.takenOnTime 
                ? Colors.green.shade600 
                : Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 200,
              left: 20,
              right: 20,
            ),
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error marking ${dose.logKey} as taken: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Future<void> _undoTaken(MedicationDose dose) async {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final logKey = dose.logKey;
    final scheduledDT = dose.scheduledDateTime;

    // Determine what the status *should* be if it weren't taken
    DoseStatus revertedStatus;
    if (now.isAfter(scheduledDT.add(const Duration(minutes: 10)))) {
      revertedStatus = DoseStatus.missed;
    } else {
      revertedStatus =
          DoseStatus.upcoming; // Or pastDue if applicable, handled by UI logic
    }

    final logUpdate = {
      logKey: FieldValue.delete(), // Remove the log entry entirely
    };

    try {
      await _firestore
          .collection('medication_log')
          .doc(widget.elderlyId)
          .collection('daily_log')
          .doc(todayKey)
          .update(logUpdate); // Use update with FieldValue.delete()

      debugPrint(
        "Firestore log reverted/deleted for ${dose.logKey}. Status should now be determined by time: ${revertedStatus.name}",
      );

      // Reschedule notifications for this user since the state changed
      await _scheduler.scheduleAllMedications(widget.elderlyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Undo successful for ${dose.medication.name}. Notifications rescheduled.',
            ),
            backgroundColor: Colors.orangeAccent, // Feedback color
          ),
        );
      }
    } catch (e) {
      debugPrint("Error undoing status for ${dose.logKey}: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error undoing status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MedicationDose>>(
      stream: _getTodaysDosesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Error in stream builder: ${snapshot.error}");
          return Center(
            child: Text('Error loading medications: ${snapshot.error}'),
          );
        }
        // Even if data is null or empty, proceed to build the structure
        // --- Start of Logic Block ---
        final doses = snapshot.data ?? [];
        DateTime now = DateTime.now();

        final List<MedicationDose> upcomingRaw = []; // Future doses
        final List<MedicationDose> takenOnTime = [];
        final List<MedicationDose> takenLate = [];
        final List<MedicationDose> missed = [];
        final List<MedicationDose> pastDueUpcoming =
            []; // Doses between 0-5 mins past due

        // 1. Corrected Categorization Loop
        for (final dose in doses) {
          final scheduledDT = dose.scheduledDateTime;
          // Define thresholds relative to NOW
          final fiveMinPastThreshold = now.subtract(const Duration(minutes: 5));
          final tenMinPastThreshold = now.subtract(const Duration(minutes: 10));

          if (dose.status == DoseStatus.takenOnTime) {
            takenOnTime.add(dose);
          } else if (dose.status == DoseStatus.takenLate) {
            takenLate.add(dose);
          } else if (dose.status == DoseStatus.missed) {
            // If logged as missed, keep it missed unless manually undone
            missed.add(dose);
          } else {
            // Status is upcoming (either from log or default)
            if (scheduledDT.isBefore(tenMinPastThreshold)) {
              // If scheduled time is more than 10 mins ago, it's missed
              missed.add(
                dose..status = DoseStatus.missed,
              ); // Update status in memory
            } else if (scheduledDT.isBefore(fiveMinPastThreshold)) {
              // If scheduled time is between 5 and 10 mins ago, it's past due
              pastDueUpcoming.add(dose);
            } else if (scheduledDT.isBefore(now) ||
                scheduledDT.isAtSameMomentAs(now)) {
              // If scheduled time is between 0 and 5 mins ago (inclusive), treat as 'Next Up' (or eligible for it)
              // We will handle grouping later, just add it to the pool of potentials
              upcomingRaw.add(dose);
            } else {
              // Genuinely scheduled for the future
              upcomingRaw.add(dose);
            }
          }
        }
        // --- End Corrected Categorization ---

        // 2. Sort lists (important after categorization)
        upcomingRaw.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        pastDueUpcoming.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        missed.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        takenOnTime.sort(
          (a, b) => (a.takenAt?.toDate() ?? a.scheduledDateTime).compareTo(
            b.takenAt?.toDate() ?? b.scheduledDateTime,
          ),
        ); // CORRECTED
        takenLate.sort(
          (a, b) => (a.takenAt?.toDate() ?? a.scheduledDateTime).compareTo(
            b.takenAt?.toDate() ?? b.scheduledDateTime,
          ),
        ); // CORRECTED

        // 3. Determine "Next Up" vs "Later Today" from upcomingRaw ONLY
        List<MedicationDose> nextUpDoses = [];
        List<MedicationDose> laterTodayDoses = [];
        DateTime? nextScheduledTimeAbsolute;

        // Find the *first* dose in upcomingRaw (which includes 0-5 min past due ones now)
        if (upcomingRaw.isNotEmpty) {
          nextScheduledTimeAbsolute = upcomingRaw.first.scheduledDateTime;

          // Group all doses AT that earliest time (could be past or future)
          nextUpDoses = upcomingRaw
              .where(
                (d) =>
                    d.scheduledDateTime.hour ==
                        nextScheduledTimeAbsolute!.hour &&
                    d.scheduledDateTime.minute ==
                        nextScheduledTimeAbsolute!.minute,
              )
              .toList();

          // Everything else in upcomingRaw that's strictly AFTER that time is later
          laterTodayDoses = upcomingRaw
              .where(
                (d) => d.scheduledDateTime.isAfter(nextScheduledTimeAbsolute!),
              )
              .toList();
        }

        // 4. Combine Taken lists and sort
        final List<MedicationDose> allTaken = [...takenOnTime, ...takenLate]
          ..sort((a, b) {
            final DateTime aCompareTime =
                a.takenAt?.toDate() ?? a.scheduledDateTime;
            final DateTime bCompareTime =
                b.takenAt?.toDate() ?? b.scheduledDateTime;
            return aCompareTime.compareTo(bCompareTime); // CORRECTED
          });
        // --- End of Logic Block ---

        // --- Build UI with Containers ---
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Container 1: Upcoming (Next Up, Past Due, Later Today) ---
            _buildStatusContainer(
              title: 'Upcoming',
              icon: Icons.notifications_active, // Or choose a better icon
              color: Colors.blue.shade700,

              children: [
                // Next Up (Show header only if items exist)
                if (nextUpDoses.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Next Up',
                    Icons.notification_important,
                    Colors.blue.shade700,
                    showHeader: false,
                  ), // Header already shown by container
                  ...nextUpDoses.map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: true,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () => _markAsTaken(dose),
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  ),
                  const SizedBox(height: 10), // Spacing between sub-sections
                ],
                // Past Due (Show header only if items exist)
                if (pastDueUpcoming.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Past Due',
                    Icons.hourglass_bottom,
                    Colors.orange.shade700,
                    showHeader: false,
                  ),
                  ...pastDueUpcoming.map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: true, // Also highlight past due
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () => _markAsTaken(dose),
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // Later Today (Show header only if items exist)
                if (laterTodayDoses.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Later Today',
                    Icons.update,
                    Colors.grey.shade600,
                    showHeader: false,
                  ),
                  ...laterTodayDoses.map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: false,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () => _markAsTaken(dose),
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  ),
                ],
                // Placeholder if all sub-sections are empty
                if (nextUpDoses.isEmpty &&
                    pastDueUpcoming.isEmpty &&
                    laterTodayDoses.isEmpty)
                  _buildEmptyPlaceholder(),
              ],
            ),
            const SizedBox(height: 20),

            // --- Container 2: Taken (On Time + Late) ---
            _buildStatusContainer(
              title: 'Taken',
              icon: Icons.check_circle,
              color: Colors.green.shade700,
              children: [
                if (allTaken.isNotEmpty)
                  ...allTaken.map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: false,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () {}, // Already taken
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  )
                else
                  _buildEmptyPlaceholder(),
              ],
            ),
            const SizedBox(height: 20),

            // --- Container 3: Missed ---
            _buildStatusContainer(
              title: 'Missed',
              icon: Icons.cancel,
              color: Colors.red.shade700,
              children: [
                if (missed.isNotEmpty)
                  ...missed.map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: false,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () =>
                          _markAsTaken(dose), // Allow taking missed
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  )
                else
                  _buildEmptyPlaceholder(),
              ],
            ),
          ],
        ); // End return ListView
      }, // End builder
    ); // End StreamBuilder
  } // End build method

  // Helper to build the main containers for each status group
  Widget _buildStatusContainer({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05), // Light background for container
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Header for the container
          Padding(
            padding: const EdgeInsets.only(
              bottom: 8.0,
            ), // Adjust padding as needed
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(), // Optional separator
          // Content (med cards or placeholder)
          ...children,
        ],
      ),
    );
  }

  // Placeholder widget for empty sections within containers
  Widget _buildEmptyPlaceholder() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20.0),
      child: Center(
        child: Text(
          'No medications in this category today.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  // Adjusted Section Header (can optionally hide it if used inside a container)
  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color, {
    bool showHeader = true,
  }) {
    if (!showHeader)
      return const SizedBox.shrink(); // Return empty if header is handled by container

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
} // End _TodaysMedsTabState

// --- _TodayMedicationCard Widget ---
class _TodayMedicationCard extends StatelessWidget {
  final MedicationDose dose;
  final bool isHighlighted;
  final bool isCaregiverView;
  final VoidCallback onTakenPressed;
  final VoidCallback onUndoPressed;

  const _TodayMedicationCard({
    required this.dose,
    this.isHighlighted = false,
    required this.isCaregiverView,
    required this.onTakenPressed,
    required this.onUndoPressed,
  });

  @override
  Widget build(BuildContext context) {
    final status = dose.status;
    final med = dose.medication;
    final time = dose.scheduledTime;
    final takenTime = dose.takenAt;
    DateTime now = DateTime.now();

    Color borderColor = Colors.grey.shade300;
    Color backgroundColor = Colors.white;
    Color headerColor = const Color(0xFF1B3A52); // Default header color
    IconData headerIcon = Icons.access_time;
    String statusText = '';
    Color statusColor = Colors.grey;

    bool canMarkAsTaken =
        !isCaregiverView && // Only elderly can mark
        (status ==
                DoseStatus.missed || // Can always mark missed as taken (late)
            (status == DoseStatus.upcoming && // Can mark upcoming if...
                !dose.scheduledDateTime.isAfter(
                  DateTime.now(),
                )) // ...scheduled time is now or in the past
            );

    bool showTakenButton = canMarkAsTaken; // Show button if it can be marked
    bool showUndoButton =
        !isCaregiverView &&
        (status == DoseStatus.takenOnTime || status == DoseStatus.takenLate);

    // --- Determine Styling Based on Status and Time ---
    // Check if the dose is strictly past the 5-minute threshold for "Past Due" styling
    bool isStrictlyPastDue =
        status == DoseStatus.upcoming &&
        dose.scheduledDateTime.add(const Duration(minutes: 5)).isBefore(now);
    // Check if the dose is the *actual* next one or within the 0-5 min past due window (highlight these)
    bool shouldHighlight =
        isHighlighted ||
        (status == DoseStatus.upcoming &&
            !isStrictlyPastDue &&
            dose.scheduledDateTime.isBefore(now));
    // Dim only if it's truly in the future AND not highlighted as the next immediate one
    bool isDimmed =
        status == DoseStatus.upcoming &&
        dose.scheduledDateTime.isAfter(now) &&
        !isHighlighted;

    switch (status) {
      case DoseStatus.takenOnTime:
        borderColor = Colors.green;
        backgroundColor = const Color(0xFFE8F5E9);
        headerColor = Colors.green.shade700;
        headerIcon = Icons.check_circle;
        statusText = 'Taken on time';
        statusColor = Colors.green;
        break;
      case DoseStatus.takenLate:
        borderColor = Colors.orange;
        backgroundColor = Colors.orange.shade50;
        headerColor = Colors.orange.shade800;
        headerIcon = Icons.check_circle; // Still check mark
        statusText = 'Taken late';
        statusColor = Colors.orange.shade800;
        break;
      case DoseStatus.missed: // (More than 10 mins late)
        borderColor = Colors.red;
        backgroundColor = Colors.red.shade50;
        headerColor = Colors.red.shade700;
        headerIcon = Icons.cancel;
        statusText = 'Missed';
        statusColor = Colors.red.shade700;
        break;
      case DoseStatus.upcoming:
        if (isStrictlyPastDue) {
          // Style for 5-10 mins past due
          borderColor = Colors.orange;
          backgroundColor = Colors.orange.shade50;
          headerColor = Colors.orange.shade700;
          headerIcon = Icons.hourglass_bottom;
          statusText = 'Past due';
          statusColor = Colors.orange.shade700;
        } else if (shouldHighlight) {
          // Style for next up (future or 0-5 mins past)
          borderColor = Colors.blue;
          backgroundColor = Colors.blue.shade50;
          headerColor = Colors.blue.shade700;
          headerIcon = Icons.notification_important;
          // Decide status text based on time relative to now
          statusText = dose.scheduledDateTime.isAfter(now)
              ? 'Next up'
              : 'Due now';
          statusColor = Colors.blue.shade700;
        } else {
          // Style for later today (genuinely future and not the immediate next)
          headerIcon = Icons.update;
          statusText = 'Upcoming';
          statusColor = Colors.grey.shade600;
        }
        break;
    }
    backgroundColor = isDimmed ? Colors.grey.shade100 : backgroundColor;
    borderColor = isDimmed ? Colors.grey.shade300 : borderColor;

    // --- Keep the Font Sizes from previous step ---
    const double timeFontSize = 24.0;
    const double statusFontSize = 16.0;
    const double takenAtFontSize = 15.0;
    const double medNameFontSize = 22.0;
    const double frequencyFontSize = 16.0;
    const double notesFontSize = 16.0;
    const double buttonFontSize = 20.0;
    const double buttonIconSize = 28.0;
    const double headerIconSize = 32.0;
    const double notesIconSize = 20.0;
    const double undoFontSize = 16.0;
    const double undoIconSize = 20.0;

    // --- Return Card Structure (mostly unchanged, just uses updated variables) ---
    return Card(
      elevation: (shouldHighlight || isStrictlyPastDue)
          ? 6
          : 2, // Highlight next up and past due (5-10min)
      margin: const EdgeInsets.only(bottom: 16),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: borderColor,
          width: (shouldHighlight || isStrictlyPastDue)
              ? 3.0
              : 2.0, // Thicker borders for highlighted
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (uses updated headerIcon, headerColor, timeFontSize, statusText, statusFontSize, takenAtFontSize)
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    headerIcon,
                    color: headerColor,
                    size: headerIconSize,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time.format(context),
                        style: TextStyle(
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.bold,
                          color: headerColor,
                        ),
                      ),
                      if (statusText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: statusFontSize,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (takenTime != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'at ${DateFormat('h:mm a').format(takenTime.toDate())}',
                            style: TextStyle(
                              fontSize: takenAtFontSize,
                              color: statusColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Medication Name (uses updated medNameFontSize, color logic remains)
            Text(
              med.name,
              style: TextStyle(
                fontSize: medNameFontSize,
                fontWeight: FontWeight.bold,
                color: status == DoseStatus.missed
                    ? Colors.red.shade700
                    : const Color(0xFF212121),
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),

            // Frequency (uses updated frequencyFontSize)
            if (med.frequency != null)
              Text(
                'Frequency: ${med.frequency}',
                style: TextStyle(
                  fontSize: frequencyFontSize,
                  color: const Color.fromARGB(255, 41, 40, 40),
                ),
              ),

            // Notes (uses updated notesFontSize, notesIconSize)
            if (med.notes != null && med.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50.withOpacity(
                      isDimmed ? 0.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Icon(
                          Icons.info_outline,
                          size: notesIconSize,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          med.notes!,
                          style: TextStyle(
                            fontSize: notesFontSize,
                            color: Colors.blueGrey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Action Buttons (uses updated canMarkAsTaken, isStrictlyPastDue, font/icon sizes)
            if (!isCaregiverView) ...[
              const SizedBox(height: 20),
              if (showTakenButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canMarkAsTaken ? onTakenPressed : null,
                    icon: Icon(
                      Icons.check_circle_outline,
                      size: buttonIconSize,
                    ),
                    label: Text(
                      // Label depends on if it's strictly past due (5-10 min) or missed (>10 min)
                      isStrictlyPastDue || status == DoseStatus.missed
                          ? 'Mark as Taken (Late)'
                          : 'Mark as Taken',
                      style: const TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canMarkAsTaken
                          ? (isStrictlyPastDue ||
                                    status ==
                                        DoseStatus
                                            .missed // Orange button for past due/missed
                                ? const Color.fromARGB(255, 225, 116, 7)
                                : const Color.fromARGB(
                                    255,
                                    29,
                                    119,
                                    113,
                                  )) // Teal for current/upcoming
                          : Colors.grey.shade400, // Disabled color
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: canMarkAsTaken ? 4 : 0,
                    ),
                  ),
                ),
              if (showUndoButton)
                Padding(
                  padding: const EdgeInsets.only(top: 10), // Spacing
                  child: SizedBox(
                    // Wrap with SizedBox to control width if needed
                    width:
                        double.infinity, // Make it wide like the other button
                    child: OutlinedButton.icon(
                      // <-- Changed to OutlinedButton.icon
                      onPressed: onUndoPressed,
                      icon: Icon(
                        Icons.undo,
                        size: undoIconSize,
                      ), // Use defined size
                      label: Text(
                        'Undo',
                        // Use defined undoFontSize
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ), // Added bold
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color.fromARGB(
                          255,
                          255,
                          255,
                          255,
                        ), // Text/icon color

                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ), // Match vertical padding
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            14,
                          ), // Match shape
                        ),
                        backgroundColor: const Color.fromARGB(255, 77, 75, 75),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
} // End _TodayMedicationCard

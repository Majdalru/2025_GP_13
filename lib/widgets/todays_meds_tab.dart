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
  final bool isCaregiverView; // Use this flag for conditional styling
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

    // --- Define Styles Based on View ---
    final double timeFontSize = isCaregiverView ? 20.0 : 24.0;
    final double statusFontSize = isCaregiverView ? 14.0 : 16.0;
    final double takenAtFontSize = isCaregiverView ? 13.0 : 15.0;
    final double medNameFontSize = isCaregiverView ? 18.0 : 22.0;
    final double frequencyFontSize = isCaregiverView ? 14.0 : 16.0;
    final double notesFontSize = isCaregiverView ? 14.0 : 16.0;
    final double buttonFontSize = isCaregiverView ? 16.0 : 20.0;
    final double buttonIconSize = isCaregiverView ? 22.0 : 28.0;
    final double headerIconSize = isCaregiverView ? 28.0 : 32.0;
    final double notesIconSize = isCaregiverView ? 18.0 : 20.0;
    final double undoIconSize = isCaregiverView ? 18.0 : 20.0;
    final double cardBorderRadius = isCaregiverView ? 16.0 : 20.0;
    final double cardPadding = isCaregiverView ? 16.0 : 20.0;
    final double cardMarginBottom = isCaregiverView ? 12.0 : 16.0;
    final double headerIconPadding = isCaregiverView ? 10.0 : 12.0;
    final double headerIconRadius = isCaregiverView ? 12.0 : 14.0;
    final double buttonVPadding = isCaregiverView ? 14.0 : 18.0;
    final double undoVPadding = isCaregiverView ? 12.0 : 16.0;
    final double buttonRadius = isCaregiverView ? 12.0 : 14.0;

    // --- Determine Styling Based on Status (Common Logic) ---
    Color baseBorderColor = Colors.grey.shade300;
    Color statusBackgroundColor = Colors.white; // Default background
    Color headerColor = const Color(0xFF1B3A52);
    IconData headerIcon = Icons.access_time;
    String statusText = '';
    Color statusColor = Colors.grey;
    double defaultBorderWidth = isCaregiverView ? 0.0 : 2.0;
    double highlightedBorderWidth = isCaregiverView ? 0.0 : 3.0;

    bool canMarkAsTaken =
        !isCaregiverView &&
        (status == DoseStatus.missed ||
            (status == DoseStatus.upcoming &&
                !dose.scheduledDateTime.isAfter(DateTime.now())));

    bool showTakenButton = canMarkAsTaken;
    bool showUndoButton =
        !isCaregiverView &&
        (status == DoseStatus.takenOnTime || status == DoseStatus.takenLate);

    bool isStrictlyPastDue =
        status == DoseStatus.upcoming &&
        dose.scheduledDateTime.add(const Duration(minutes: 5)).isBefore(now);
    bool shouldHighlight =
        isHighlighted ||
        (status == DoseStatus.upcoming &&
            !isStrictlyPastDue &&
            dose.scheduledDateTime.isBefore(now));
    bool isDimmed =
        status == DoseStatus.upcoming &&
        dose.scheduledDateTime.isAfter(now) &&
        !isHighlighted;

    // Determine status-specific colors and icons (used for elderly bg and both views' icons/text)
    switch (status) {
      case DoseStatus.takenOnTime:
        baseBorderColor = Colors.green;
        statusBackgroundColor = const Color(0xFFE8F5E9); // Light green
        headerColor = Colors.green.shade700;
        headerIcon = Icons.check_circle;
        statusText = 'Taken on time';
        statusColor = Colors.green;
        break;
      case DoseStatus.takenLate:
        baseBorderColor = Colors.orange;
        statusBackgroundColor = Colors.orange.shade50; // Light orange
        headerColor = Colors.orange.shade800;
        headerIcon = Icons.check_circle;
        statusText = 'Taken late';
        statusColor = Colors.orange.shade800;
        break;
      case DoseStatus.missed:
        baseBorderColor = Colors.red;
        statusBackgroundColor = Colors.red.shade50; // Light red
        headerColor = Colors.red.shade700;
        headerIcon = Icons.cancel;
        statusText = 'Missed';
        statusColor = Colors.red.shade700;
        break;
      case DoseStatus.upcoming:
        if (isStrictlyPastDue) {
          baseBorderColor = Colors.orange;
          statusBackgroundColor = Colors.orange.shade50; // Light orange
          headerColor = Colors.orange.shade700;
          headerIcon = Icons.hourglass_bottom;
          statusText = 'Past due';
          statusColor = Colors.orange.shade700;
        } else if (shouldHighlight) {
          baseBorderColor = Colors.blue;
          statusBackgroundColor = Colors.blue.shade50; // Light blue
          headerColor = Colors.blue.shade700;
          headerIcon = Icons.notification_important;
          statusText = dose.scheduledDateTime.isAfter(now)
              ? 'Next up'
              : 'Due now';
          statusColor = Colors.blue.shade700;
        } else {
          headerIcon = Icons.update;
          statusText = 'Upcoming';
          statusColor = Colors.grey.shade600;
          baseBorderColor = Colors.grey.shade300;
          statusBackgroundColor = Colors.grey.shade100; // Dimmed background
        }
        break;
    }

    // --- Final Background Color Logic ---
    // If it's caregiver view, always use white.
    // Otherwise, use the status-determined color (or dimmed grey).
    final Color finalBackgroundColor = isCaregiverView
        ? Colors.white
        : (isDimmed ? Colors.grey.shade100 : statusBackgroundColor);

    final Color finalBorderColor = isDimmed
        ? Colors.grey.shade300
        : baseBorderColor;
    final double finalBorderWidth = (shouldHighlight || isStrictlyPastDue)
        ? highlightedBorderWidth
        : defaultBorderWidth;

    // --- Return Card Structure ---
    return Card(
      elevation: (shouldHighlight || isStrictlyPastDue)
          ? (isCaregiverView ? 2 : 6)
          : (isCaregiverView ? 1 : 2),
      margin: EdgeInsets.only(bottom: cardMarginBottom),
      color: finalBackgroundColor, // Use the final calculated background color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardBorderRadius),
        side: isCaregiverView
            ? BorderSide.none
            : BorderSide(color: finalBorderColor, width: finalBorderWidth),
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (rest of the code remains the same)
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(headerIconPadding),
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(headerIconRadius),
                  ),
                  child: Icon(
                    headerIcon,
                    color: headerColor,
                    size: headerIconSize,
                  ),
                ),
                const SizedBox(width: 12),
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
            const SizedBox(height: 12),

            // Medication Name
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
            const SizedBox(height: 8),

            // Frequency
            if (med.frequency != null)
              Text(
                'Frequency: ${med.frequency}',
                style: TextStyle(
                  fontSize: frequencyFontSize,
                  color: const Color.fromARGB(255, 41, 40, 40),
                ),
              ),

            // Notes
            if (med.notes != null && med.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50.withOpacity(
                      isDimmed ? 0.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1.0),
                        child: Icon(
                          Icons.info_outline,
                          size: notesIconSize,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
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

            // Action Buttons (Only shown for Elderly View)
            if (!isCaregiverView) ...[
              const SizedBox(height: 16),
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
                      isStrictlyPastDue || status == DoseStatus.missed
                          ? 'Mark as Taken (Late)'
                          : 'Mark as Taken',
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canMarkAsTaken
                          ? (isStrictlyPastDue || status == DoseStatus.missed
                                ? const Color.fromARGB(255, 225, 116, 7)
                                : const Color.fromARGB(255, 29, 119, 113))
                          : Colors.grey.shade400,
                      foregroundColor: const Color.fromARGB(255, 255, 255, 255),
                      padding: EdgeInsets.symmetric(vertical: buttonVPadding),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(buttonRadius),
                      ),
                      elevation: canMarkAsTaken ? (isCaregiverView ? 2 : 4) : 0,
                    ),
                  ),
                ),
              if (showUndoButton)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onUndoPressed,
                      icon: Icon(Icons.undo, size: undoIconSize),
                      label: const Text(
                        'Undo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color.fromARGB(
                          255,
                          255,
                          255,
                          255,
                        ),
                        padding: EdgeInsets.symmetric(vertical: undoVPadding),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(buttonRadius),
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

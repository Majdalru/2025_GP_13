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
    if (now.isAfter(scheduledDT.add(const Duration(seconds: 1)))) {
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
            content: Text(
              '${dose.medication.name} marked as taken (${newStatus == DoseStatus.takenOnTime ? "on time" : "late"}).',
            ),
            backgroundColor: Colors.green, // Give feedback color
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
        final doses = snapshot.data ?? []; // Use empty list if no data
        DateTime now = DateTime.now();

        // --- Logic Block (copied from previous response) ---
        final List<MedicationDose> upcomingRaw = [];
        final List<MedicationDose> takenOnTime = [];
        final List<MedicationDose> takenLate = [];
        final List<MedicationDose> missed = [];
        final List<MedicationDose> pastDueUpcoming = [];

        for (final dose in doses) {
          final scheduledDT = dose.scheduledDateTime;
          final tenMinLate = scheduledDT.add(const Duration(minutes: 10));

          if (dose.status == DoseStatus.takenOnTime) {
            takenOnTime.add(dose);
          } else if (dose.status == DoseStatus.takenLate) {
            takenLate.add(dose);
          } else if (dose.status == DoseStatus.missed) {
            missed.add(dose);
          } else {
            // DoseStatus.upcoming from log or default
            if (now.isAfter(tenMinLate)) {
              missed.add(dose..status = DoseStatus.missed);
            } else if (now.isAfter(scheduledDT)) {
              pastDueUpcoming.add(dose);
            } else {
              upcomingRaw.add(dose);
            }
          }
        }

        upcomingRaw.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        pastDueUpcoming.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        missed.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );

        List<MedicationDose> nextUpDoses = [];
        List<MedicationDose> laterTodayDoses = [];
        DateTime? nextScheduledTimeAbsolute;

        final nextDose = upcomingRaw.firstWhereOrNull(
          (d) => !d.scheduledDateTime.isBefore(now),
        );

        if (nextDose != null) {
          nextScheduledTimeAbsolute = nextDose.scheduledDateTime;
          nextUpDoses = upcomingRaw
              .where(
                (d) =>
                    d.scheduledDateTime.hour ==
                        nextScheduledTimeAbsolute!.hour &&
                    d.scheduledDateTime.minute ==
                        nextScheduledTimeAbsolute!.minute,
              )
              .toList();
          laterTodayDoses = upcomingRaw
              .where(
                (d) => d.scheduledDateTime.isAfter(nextScheduledTimeAbsolute!),
              )
              .toList();
        } else {
          laterTodayDoses = List.from(upcomingRaw);
        }

        final List<MedicationDose> allTaken = [...takenOnTime, ...takenLate]
          ..sort((a, b) {
            final DateTime aCompareTime =
                a.takenAt?.toDate() ?? a.scheduledDateTime;
            final DateTime bCompareTime =
                b.takenAt?.toDate() ?? b.scheduledDateTime;
            return aCompareTime.compareTo(
              bCompareTime,
            ); // Sort taken items chronologically
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

    // Define colors and styles based on status
    Color borderColor = Colors.grey.shade300;
    Color backgroundColor = Colors.white;
    Color headerColor = const Color(0xFF1B3A52); // Default header color
    IconData headerIcon = Icons.access_time;
    String statusText = '';
    Color statusColor = Colors.grey;
    bool showTakenButton =
        !isCaregiverView &&
        (status == DoseStatus.upcoming ||
            status == DoseStatus.missed ||
            dose.status == DoseStatus.missed); // Keep previous logic
    bool showUndoButton =
        !isCaregiverView &&
        (status == DoseStatus.takenOnTime || status == DoseStatus.takenLate);
    bool isDimmed = status == DoseStatus.upcoming && !isHighlighted;

    // Determine if it's past due (used for highlighting and potentially status text)
    bool isPastDue =
        !isDimmed &&
        status == DoseStatus.upcoming &&
        dose.scheduledDateTime.isBefore(DateTime.now());

    switch (status) {
      case DoseStatus.takenOnTime:
        borderColor = Colors.green;
        backgroundColor = Colors.green.shade50;
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
      case DoseStatus.missed:
        borderColor = Colors.red;
        backgroundColor = Colors.red.shade50;
        headerColor = Colors.red.shade700;
        headerIcon = Icons.cancel;
        statusText = 'Missed';
        statusColor = Colors.red.shade700;
        break;
      case DoseStatus.upcoming:
        if (isPastDue) {
          // Style for past due but not yet missed
          borderColor = Colors.orange;
          backgroundColor = Colors.orange.shade50;
          headerColor = Colors.orange.shade700;
          headerIcon = Icons.hourglass_bottom;
          statusText = 'Past due';
          statusColor = Colors.orange.shade700;
        } else if (isHighlighted) {
          // Style for next up
          borderColor = Colors.blue;
          backgroundColor = Colors.blue.shade50;
          headerColor = Colors.blue.shade700;
          headerIcon = Icons.notification_important;
          statusText = 'Next up';
          statusColor = Colors.blue.shade700;
        } else {
          // Style for later today
          headerIcon = Icons.update;
          statusText = 'Upcoming';
          statusColor = Colors.grey.shade600;
        }
        break;
    }

    // Apply dimming if needed (only for future 'upcoming')
    backgroundColor = isDimmed ? Colors.grey.shade100 : backgroundColor;
    borderColor = isDimmed ? Colors.grey.shade300 : borderColor;

    // --- Define Larger Font Sizes ---
    const double timeFontSize = 24.0; // Larger scheduled time
    const double statusFontSize = 18.0; // Slightly larger status text
    const double takenAtFontSize = 16.0; // Slightly larger 'taken at' time
    const double medNameFontSize = 24.0; // Larger medication name
    const double frequencyFontSize = 18.0; // Larger frequency text
    const double notesFontSize = 18.0; // Larger notes text
    const double buttonFontSize = 22.0; // Larger button text
    const double buttonIconSize = 30.0; // Larger button icon
    const double headerIconSize = 34.0; // Larger header icon
    const double notesIconSize = 22.0; // Slightly larger notes icon
    const double undoFontSize = 18.0; // Larger undo text
    const double undoIconSize = 22.0; // Larger undo icon

    return Card(
      elevation: (isHighlighted || isPastDue)
          ? 6
          : 2, // Highlight next up and past due
      margin: const EdgeInsets.only(bottom: 16),
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Slightly larger radius
        side: BorderSide(
          color: borderColor,
          width: (isHighlighted || isPastDue) ? 3.0 : 2.0, // Thicker borders
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0), // Increased padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12), // Slightly larger padding
                  decoration: BoxDecoration(
                    color: headerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      14,
                    ), // Slightly larger radius
                  ),
                  // Use defined headerIconSize
                  child: Icon(
                    headerIcon,
                    color: headerColor,
                    size: headerIconSize,
                  ),
                ),
                const SizedBox(width: 14), // Increased spacing
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // Scheduled Time
                        time.format(context),
                        style: TextStyle(
                          // Use defined timeFontSize
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.bold,
                          color: headerColor,
                        ),
                      ),
                      if (statusText.isNotEmpty)
                        Padding(
                          // Add padding below time if status exists
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            // Status Text
                            statusText,
                            style: TextStyle(
                              // Use defined statusFontSize
                              fontSize: statusFontSize,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (takenTime != null) // Display Taken Timestamp
                        Padding(
                          // Add padding below status if taken time exists
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            'at ${DateFormat('h:mm a').format(takenTime.toDate())}',
                            style: TextStyle(
                              // Use defined takenAtFontSize
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
            const SizedBox(height: 16), // Increased spacing
            // Medication name
            Text(
              med.name,
              style: TextStyle(
                // Use defined medNameFontSize
                fontSize: medNameFontSize,
                fontWeight: FontWeight.bold,
                color: status == DoseStatus.missed
                    ? Colors.red.shade700
                    : const Color(0xFF212121),
                decoration: TextDecoration.none, // Ensure no strikethrough
              ),
            ),
            const SizedBox(height: 10), // Increased spacing
            // Frequency
            if (med.frequency != null)
              Text(
                'Frequency: ${med.frequency}',
                // Use defined frequencyFontSize
                style: TextStyle(
                  fontSize: frequencyFontSize,
                  color: Colors.grey.shade700,
                ),
              ),

            // Notes
            if (med.notes != null && med.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12), // Increased spacing
                child: Container(
                  padding: const EdgeInsets.all(12), // Slightly larger padding
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50.withOpacity(
                      isDimmed ? 0.5 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(
                      10,
                    ), // Slightly larger radius
                    border: Border.all(color: Colors.blueGrey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start, // Align icon top
                    children: [
                      // Use defined notesIconSize
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 2.0,
                        ), // Adjust icon position if needed
                        child: Icon(
                          Icons.info_outline,
                          size: notesIconSize,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                      const SizedBox(width: 10), // Increased spacing
                      Expanded(
                        child: Text(
                          med.notes!,
                          // Use defined notesFontSize
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

            // Action Buttons
            if (!isCaregiverView) ...[
              const SizedBox(height: 20), // Increased spacing
              if (showTakenButton)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onTakenPressed,
                    // Use defined buttonIconSize
                    icon: Icon(
                      Icons.check_circle_outline,
                      size: buttonIconSize,
                    ),
                    label: Text(
                      status == DoseStatus.missed
                          ? 'Mark as Taken (Late)'
                          : 'Mark as Taken',
                      // Use defined buttonFontSize
                      style: const TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          status == DoseStatus.missed ||
                              isPastDue // Orange button for missed/past due
                          ? Colors.orange.shade700
                          : const Color(
                              0xFF5FA5A0,
                            ), // Teal for regular upcoming
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ), // Increased padding
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ), // Slightly larger radius
                      elevation: 4,
                    ),
                  ),
                ),
              if (showUndoButton)
                Padding(
                  padding: const EdgeInsets.only(top: 10), // Increased spacing
                  child: Center(
                    child: TextButton.icon(
                      onPressed: onUndoPressed,
                      // Use defined undoIconSize
                      icon: Icon(Icons.undo, size: undoIconSize),
                      label: Text(
                        'Undo',
                        // Use defined undoFontSize
                        style: TextStyle(fontSize: undoFontSize),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ), // Add padding to undo button
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

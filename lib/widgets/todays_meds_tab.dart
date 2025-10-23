import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/medication.dart'; // Make sure DoseStatus is defined here
import '../services/medication_scheduler.dart';
import 'package:collection/collection.dart'; // For groupBy, firstWhereOrNull

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

  @override
  void initState() {
    super.initState();
    // Debug notifications on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugNotifications();
    });
  }

  Future<void> _debugNotifications() async {
    try {
      final pending = await _scheduler.getPendingNotifications();
      debugPrint('=== PENDING NOTIFICATIONS (${pending.length}) ===');
      for (final notif in pending) {
        debugPrint(
          'ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}',
        );
      }
      debugPrint('================================');
    } catch (e) {
      debugPrint('Error debugging notifications: $e');
    }
  }

  Stream<List<MedicationDose>> _getTodaysDosesStream() {
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final todayName = DateFormat('EEEE').format(now); // e.g., 'Monday'

    // Stream for medications
    final medsStream = _firestore
        .collection('medications')
        .doc(widget.elderlyId)
        .snapshots();

    // Also watch the log for real-time updates
    final logStream = _firestore
        .collection('medication_log')
        .doc(widget.elderlyId)
        .collection('daily_log')
        .doc(todayKey)
        .snapshots();

    // Combine both streams
    return medsStream.asyncMap((medsSnapshot) async {
      // 1. Get medications scheduled for today
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
        debugPrint(
          "No medications scheduled for today for ${widget.elderlyId}.",
        );
        return <MedicationDose>[];
      }

      // 2. Get today's log data (if exists)
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

      // 3. Create MedicationDose objects
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
          final fiveMinLate = scheduledDT.add(const Duration(minutes: 5));
          final tenMinLate = scheduledDT.add(const Duration(minutes: 10));

          // Update status from log first
          final doseLog = logData[dose.logKey] as Map<String, dynamic>?;
          if (doseLog != null) {
            dose.status = _parseDoseStatus(doseLog['status'] as String?);
            dose.takenAt = doseLog['takenAt'] as Timestamp?;
          } else {
            // If not in log, determine if upcoming or missed based on time
            if (currentTime.isAfter(tenMinLate)) {
              dose.status = DoseStatus.missed;
            } else if (currentTime.isAfter(fiveMinLate)) {
              dose.status = DoseStatus.upcoming; // Still upcoming but late
            } else {
              dose.status = DoseStatus.upcoming;
            }
          }
          doses.add(dose);
        }
      }

      // 4. Sort doses initially by time
      doses.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

      return doses;
    });
  }

  DoseStatus _parseDoseStatus(String? statusString) {
    switch (statusString) {
      case 'taken_on_time':
        return DoseStatus.takenOnTime;
      case 'taken_late':
        return DoseStatus.takenLate;
      case 'missed':
        return DoseStatus.missed;
      case 'upcoming':
        return DoseStatus.upcoming;
      default:
        return DoseStatus.upcoming;
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
        return 'upcoming';
    }
  }

  Future<void> _markAsTaken(MedicationDose dose) async {
    final now = DateTime.now();
    final scheduledDT = dose.scheduledDateTime;
    final logKey = dose.logKey;
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    DoseStatus newStatus;
    if (now.isBefore(scheduledDT.add(const Duration(minutes: 5)))) {
      newStatus = DoseStatus.takenOnTime;
    } else {
      newStatus = DoseStatus.takenLate;
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

      if (newStatus == DoseStatus.takenLate) {
        await _scheduler.notifyCaregiversTakenLate(
          elderlyId: widget.elderlyId,
          medication: dose.medication,
          takenAt: now,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${dose.medication.name} marked as taken (${newStatus == DoseStatus.takenOnTime ? "on time" : "late"}).',
            ),
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

    DoseStatus revertedStatus;
    if (now.isAfter(scheduledDT.add(const Duration(minutes: 10)))) {
      revertedStatus = DoseStatus.missed;
    } else {
      revertedStatus = DoseStatus.upcoming;
    }

    final logUpdate = {
      logKey: {
        'status': _statusToString(revertedStatus),
        'takenAt': null, // Remove timestamp
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
        "Firestore log reverted for ${dose.logKey} to ${revertedStatus.name}",
      );

      await _scheduler.scheduleAllMedications(widget.elderlyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Undo successful for ${dose.medication.name}. Notifications rescheduled.',
            ),
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
    final now = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    return StreamBuilder<List<MedicationDose>>(
      stream: _getTodaysDosesStream(),
      builder: (context, snapshot) {
        // --- Initial Checks ---
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint("Error in stream builder: ${snapshot.error}");
          return Center(
            child: Text('Error loading medications: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No medications scheduled for today.',
              style: TextStyle(fontSize: 18),
            ),
          );
        }

        // --- Start of Refined Logic Block ---
        final doses = snapshot.data!;
        final currentTime = DateTime.now();

        // Define the lists
        final List<MedicationDose> upcoming = [];
        final List<MedicationDose> takenOnTime = [];
        final List<MedicationDose> takenLate = [];
        final List<MedicationDose> missed = [];

        // Separate doses by status FIRST, re-evaluating missed status
        for (final dose in doses) {
          final scheduledDT = dose.scheduledDateTime;
          final tenMinLate = scheduledDT.add(const Duration(minutes: 10));

          // If dose is upcoming but current time is past 10 minutes late, mark as missed
          if (dose.status == DoseStatus.upcoming &&
              currentTime.isAfter(tenMinLate)) {
            missed.add(dose..status = DoseStatus.missed);
          } else {
            switch (dose.status) {
              case DoseStatus.upcoming:
                upcoming.add(dose);
                break;
              case DoseStatus.takenOnTime:
                takenOnTime.add(dose);
                break;
              case DoseStatus.takenLate:
                takenLate.add(dose);
                break;
              case DoseStatus.missed:
                missed.add(dose);
                break;
            }
          }
        }

        // --- Logic to determine "Next Up" vs "Later Today" ---
        List<MedicationDose> nextUpDoses = [];
        List<MedicationDose> laterTodayDoses = [];

        if (upcoming.isNotEmpty) {
          // Sort upcoming doses by time
          upcoming.sort(
            (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
          );

          // Find the next dose that hasn't passed its missed threshold
          MedicationDose? nextDose;
          for (final dose in upcoming) {
            final missedThreshold = dose.scheduledDateTime.add(
              const Duration(minutes: 10),
            );
            if (currentTime.isBefore(missedThreshold)) {
              nextDose = dose;
              break;
            }
          }

          if (nextDose != null) {
            // Group doses by the same scheduled time
            final nextTime = nextDose.scheduledTime;
            nextUpDoses = upcoming
                .where(
                  (dose) =>
                      dose.scheduledTime.hour == nextTime.hour &&
                      dose.scheduledTime.minute == nextTime.minute,
                )
                .toList();

            // All other upcoming doses go to "Later Today"
            laterTodayDoses = upcoming
                .where((dose) => !nextUpDoses.contains(dose))
                .toList();
          } else {
            // If no upcoming doses (all missed), move all to missed section
            missed.addAll(upcoming);
            upcoming.clear();
          }
        }

        // Define allTaken
        final List<MedicationDose> allTaken = [...takenOnTime, ...takenLate]
          ..sort((a, b) {
            final DateTime aCompareTime =
                a.takenAt?.toDate() ?? a.scheduledDateTime;
            final DateTime bCompareTime =
                b.takenAt?.toDate() ?? b.scheduledDateTime;
            return aCompareTime.compareTo(bCompareTime);
          });

        missed.sort(
          (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
        );
        // --- End of Refined Logic Block ---

        // --- Return the ListView using the calculated lists ---
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Next Upcoming Section ---
            if (nextUpDoses.isNotEmpty) ...[
              _buildSectionHeader(
                'Next Up',
                Icons.notification_important,
                Colors.blue.shade700,
              ),
              ...nextUpDoses
                  .map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: true,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () => _markAsTaken(dose),
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 20),
            ],

            // --- Later Today Section ---
            if (laterTodayDoses.isNotEmpty) ...[
              _buildSectionHeader(
                'Later Today',
                Icons.update,
                Colors.grey.shade600,
              ),
              ...laterTodayDoses
                  .map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: false,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () => _markAsTaken(dose),
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 20),
            ],

            // --- Taken Section ---
            if (allTaken.isNotEmpty) ...[
              _buildSectionHeader(
                'Taken',
                Icons.check_circle,
                Colors.green.shade700,
              ),
              ...allTaken
                  .map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: false,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () {}, // Already taken
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  )
                  .toList(),
              const SizedBox(height: 20),
            ],

            // --- Missed Section ---
            if (missed.isNotEmpty) ...[
              _buildSectionHeader('Missed', Icons.cancel, Colors.red.shade700),
              ...missed
                  .map(
                    (dose) => _TodayMedicationCard(
                      dose: dose,
                      isHighlighted: false,
                      isCaregiverView: widget.isCaregiverView,
                      onTakenPressed: () =>
                          _markAsTaken(dose), // Allow taking missed
                      onUndoPressed: () => _undoTaken(dose),
                    ),
                  )
                  .toList(),
            ],

            // Debug button (remove in production)
            if (!widget.isCaregiverView) ...[
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _debugNotifications,
                  child: const Text('Debug Notifications'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
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
}

// --- _TodayMedicationCard Widget ---
class _TodayMedicationCard extends StatelessWidget {
  final MedicationDose dose;
  final bool isHighlighted; // For 'Next Up'
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
    Color headerColor = const Color(0xFF1B3A52);
    IconData headerIcon = Icons.access_time;
    String statusText = '';
    Color statusColor = Colors.grey;
    bool showTakenButton =
        !isCaregiverView &&
        (status == DoseStatus.upcoming || status == DoseStatus.missed);
    bool showUndoButton =
        !isCaregiverView &&
        (status == DoseStatus.takenOnTime || status == DoseStatus.takenLate);
    bool isDimmed = status == DoseStatus.upcoming && !isHighlighted;

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
        headerIcon = Icons.check_circle;
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
        if (isHighlighted) {
          borderColor = Colors.blue;
          backgroundColor = Colors.blue.shade50;
          headerColor = Colors.blue.shade700;
          headerIcon = Icons.notification_important;
          statusText = 'Next up';
          statusColor = Colors.blue.shade700;
        } else {
          headerIcon = Icons.update;
          statusText = 'Upcoming';
          statusColor = Colors.grey.shade600;
        }
        break;
    }

    return Opacity(
      opacity: isDimmed ? 0.65 : 1.0,
      child: Card(
        elevation: isHighlighted ? 6 : 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: borderColor,
            width: isHighlighted ? 2.5 : 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with time and status icon/text
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: headerColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(headerIcon, color: headerColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time.format(context),
                          style: TextStyle(
                            fontSize: isHighlighted ? 22 : 20,
                            fontWeight: FontWeight.bold,
                            color: headerColor,
                          ),
                        ),
                        if (statusText.isNotEmpty)
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 14,
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (takenTime != null)
                          Text(
                            'at ${DateFormat('h:mm a').format(takenTime.toDate())}',
                            style: TextStyle(
                              fontSize: 13,
                              color: statusColor.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Medication name
              Text(
                med.name,
                style: TextStyle(
                  fontSize: isHighlighted ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF212121),
                  decoration: (status == DoseStatus.missed && takenTime == null)
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  decorationColor: Colors.red,
                  decorationThickness: 2.0,
                ),
              ),
              const SizedBox(height: 8),

              // Frequency (Optional)
              if (med.frequency != null)
                Text(
                  'Frequency: ${med.frequency}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),

              // Notes (Optional)
              if (med.notes != null && med.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(
                        isDimmed ? 0.5 : 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            med.notes!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Action Buttons (Elderly View Only)
              if (!isCaregiverView) ...[
                const SizedBox(height: 16),
                if (showTakenButton)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onTakenPressed,
                      icon: const Icon(Icons.check_circle_outline, size: 24),
                      label: Text(
                        status == DoseStatus.missed
                            ? 'Mark as Taken (Late)'
                            : 'Mark as Taken',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status == DoseStatus.missed
                            ? Colors.orange.shade700
                            : const Color(0xFF5FA5A0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                if (showUndoButton)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: onUndoPressed,
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('Undo'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

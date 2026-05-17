import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/medication.dart'; // Make sure DoseStatus is defined here
import 'package:flutter_application_1/l10n/app_localizations.dart';
import '../services/medication_scheduler.dart';

// Combined data class for display
class MedicationDose {
  final Medication medication;
  final TimeOfDay scheduledTime;
  final int timeIndex; // Original index from Medication.times
  DoseStatus status;
  Timestamp? takenAt;
  final bool isFromHistory; // true if med was deleted/expired today

  MedicationDose({
    required this.medication,
    required this.scheduledTime,
    required this.timeIndex,
    this.status = DoseStatus.upcoming,
    this.takenAt,
    this.isFromHistory = false,
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

  // 0=All 1=Upcoming 2=Taken 3=Missed
  int _filter = 0;

  // --- ADD THIS BLOCK START ---
  String _elderlyName = 'The elderly';

  @override
  void initState() {
    super.initState();
    // Only fetch the name if we are in the caregiver view
    if (widget.isCaregiverView) {
      _fetchElderlyName();
    }
  }

  Future<void> _fetchElderlyName() async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(widget.elderlyId)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final first = data['firstName'] as String? ?? '';
          final last = data['lastName'] as String? ?? '';
          final fullName = '$first $last'.trim();

          if (mounted && fullName.isNotEmpty) {
            setState(() {
              _elderlyName = fullName;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching elderly name: $e');
    }
  }

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
      final Set<String> activeMedIds =
          {}; // Track active med IDs to avoid duplicates

      if (medsSnapshot.exists && medsSnapshot.data()?['medsList'] != null) {
        final allMeds = (medsSnapshot.data()!['medsList'] as List)
            .map((m) => Medication.fromMap(m as Map<String, dynamic>))
            .toList();
        for (final med in allMeds) {
          if (med.days.contains('Every day') || med.days.contains(todayName)) {
            scheduledMeds.add(med);
            activeMedIds.add(med.id);
          }
        }
      }

      // ✅ Also fetch medications from history that were deleted/expired today
      final List<Medication> historyMeds = [];
      try {
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));

        final historySnapshot = await _firestore
            .collection('medications')
            .doc(widget.elderlyId)
            .collection('history')
            .where(
              'deletedAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
            )
            .where('deletedAt', isLessThan: Timestamp.fromDate(todayEnd))
            .get();

        for (final doc in historySnapshot.docs) {
          final med = Medication.fromMap(doc.data());
          // Only add if not already in active list and scheduled for today
          if (!activeMedIds.contains(med.id) &&
              (med.days.contains('Every day') ||
                  med.days.contains(todayName))) {
            historyMeds.add(med);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error fetching history for today: $e');
      }

      if (scheduledMeds.isEmpty && historyMeds.isEmpty) {
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

      // Build doses from active medications
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
            if (currentTime.isAfter(missedThresholdTime)) {
              dose.status = DoseStatus.missed;
            } else {
              dose.status = DoseStatus.upcoming;
            }
          }
          doses.add(dose);
        }
      }

      // ✅ Build doses from history medications (deleted/expired today)
      for (final med in historyMeds) {
        for (int i = 0; i < med.times.length; i++) {
          final time = med.times[i];
          final dose = MedicationDose(
            medication: med,
            scheduledTime: time,
            timeIndex: i,
            isFromHistory: true,
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
            if (currentTime.isAfter(missedThresholdTime)) {
              dose.status = DoseStatus.missed;
            } else {
              dose.status = DoseStatus.upcoming;
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
              AppLocalizations.of(
                context,
              )!.undoSuccessful(dose.medication.name),
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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // ── Filter chips ──────────────────────────────────────
            _buildFilterChips(context, missed),

            const SizedBox(height: 16),

            // ── Missed warning banner (always shown if any) ───────
            if (missed.isNotEmpty && _filter != 2) // hide when "Taken" selected
              _buildMissedBanner(context, missed),

            // ── Content based on filter ───────────────────────────
            if (_filter == 0) ...[
              // ALL — show upcoming, taken, missed in order
              if (nextUpDoses.isNotEmpty ||
                  pastDueUpcoming.isNotEmpty ||
                  laterTodayDoses.isNotEmpty)
                _buildSectionLabel(
                  context,
                  AppLocalizations.of(context)!.upcoming,
                  Icons.notifications_active_outlined,
                  const Color(0xFF4DB6AC),
                ),
              ...nextUpDoses.map(
                (dose) => _TodayMedicationCard(
                  dose: dose,
                  isHighlighted: true,
                  isCaregiverView: widget.isCaregiverView,
                  onTakenPressed: () => _markAsTaken(dose),
                  onUndoPressed: () => _undoTaken(dose),
                ),
              ),
              ...pastDueUpcoming.map(
                (dose) => _TodayMedicationCard(
                  dose: dose,
                  isHighlighted: true,
                  isCaregiverView: widget.isCaregiverView,
                  onTakenPressed: () => _markAsTaken(dose),
                  onUndoPressed: () => _undoTaken(dose),
                ),
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
              if (allTaken.isNotEmpty) ...[
                _buildSectionLabel(
                  context,
                  AppLocalizations.of(context)!.taken,
                  Icons.check_circle_outline,
                  Colors.green.shade700,
                ),
                ...allTaken.map(
                  (dose) => _TodayMedicationCard(
                    dose: dose,
                    isHighlighted: false,
                    isCaregiverView: widget.isCaregiverView,
                    onTakenPressed: () {},
                    onUndoPressed: () => _undoTaken(dose),
                  ),
                ),
              ],
              if (missed.isNotEmpty) ...[
                _buildSectionLabel(
                  context,
                  AppLocalizations.of(context)!.missedTitle,
                  Icons.cancel_outlined,
                  Colors.red.shade700,
                ),
                ...missed.map(
                  (dose) => _TodayMedicationCard(
                    dose: dose,
                    isHighlighted: false,
                    isCaregiverView: widget.isCaregiverView,
                    onTakenPressed: () => _markAsTaken(dose),
                    onUndoPressed: () => _undoTaken(dose),
                  ),
                ),
              ],
              if (nextUpDoses.isEmpty &&
                  pastDueUpcoming.isEmpty &&
                  laterTodayDoses.isEmpty &&
                  allTaken.isEmpty &&
                  missed.isEmpty)
                _buildEmptyPlaceholder(),
            ] else if (_filter == 1) ...[
              // UPCOMING
              ...nextUpDoses.map(
                (dose) => _TodayMedicationCard(
                  dose: dose,
                  isHighlighted: true,
                  isCaregiverView: widget.isCaregiverView,
                  onTakenPressed: () => _markAsTaken(dose),
                  onUndoPressed: () => _undoTaken(dose),
                ),
              ),
              ...pastDueUpcoming.map(
                (dose) => _TodayMedicationCard(
                  dose: dose,
                  isHighlighted: true,
                  isCaregiverView: widget.isCaregiverView,
                  onTakenPressed: () => _markAsTaken(dose),
                  onUndoPressed: () => _undoTaken(dose),
                ),
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
              if (nextUpDoses.isEmpty &&
                  pastDueUpcoming.isEmpty &&
                  laterTodayDoses.isEmpty)
                _buildEmptyPlaceholder(),
            ] else if (_filter == 2) ...[
              // TAKEN
              ...allTaken.map(
                (dose) => _TodayMedicationCard(
                  dose: dose,
                  isHighlighted: false,
                  isCaregiverView: widget.isCaregiverView,
                  onTakenPressed: () {},
                  onUndoPressed: () => _undoTaken(dose),
                ),
              ),
              if (allTaken.isEmpty) _buildEmptyPlaceholder(),
            ] else ...[
              // MISSED
              ...missed.map(
                (dose) => _TodayMedicationCard(
                  dose: dose,
                  isHighlighted: false,
                  isCaregiverView: widget.isCaregiverView,
                  onTakenPressed: () => _markAsTaken(dose),
                  onUndoPressed: () => _undoTaken(dose),
                ),
              ),
              if (missed.isEmpty) _buildEmptyPlaceholder(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context, List<MedicationDose> missed) {
    final loc = AppLocalizations.of(context)!;
    const kTeal = Color(0xFF4DB6AC);
    final labels = [loc.all, loc.upcoming, loc.taken, loc.missedTitle];
    final colors = [kTeal, kTeal, Colors.green.shade700, Colors.red.shade700];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _filter == i;
          final color = colors[i];
          final hasBadge = i == 3 && missed.isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected ? color : const Color(0xFFE5E7EB),
                    width: 1.5,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    if (hasBadge) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.red.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${missed.length}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: selected
                                ? Colors.red.shade700
                                : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionLabel(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 0, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.noMedicationsFound,
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildMissedBanner(BuildContext context, List<MedicationDose> missed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.red.shade800,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isCaregiverView
                  ? AppLocalizations.of(
                      context,
                    )!.elderlyMissedDoses(_elderlyName, missed.length)
                  : AppLocalizations.of(context)!.youMissedDoses(missed.length),
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color, {
    bool showHeader = true,
  }) {
    if (!showHeader) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
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

// ══════════════════════════════════════════════════════════════
// _TodayMedicationCard — redesigned, clear for elderly
// ══════════════════════════════════════════════════════════════
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
    final now = DateTime.now();
    final loc = AppLocalizations.of(context)!;
    const kBlue = Color(0xFF102E50);

    final double nameFontSize = isCaregiverView ? 18.0 : 22.0;
    final double subFontSize = isCaregiverView ? 15.0 : 17.0;
    final double buttonFontSize = isCaregiverView ? 17.0 : 20.0;
    final double buttonVPad = isCaregiverView ? 13.0 : 17.0;

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

    bool canMarkAsTaken =
        !isCaregiverView &&
        (status == DoseStatus.missed ||
            (status == DoseStatus.upcoming &&
                !dose.scheduledDateTime.isAfter(now)));
    bool showTakenButton = canMarkAsTaken;
    bool showUndoButton =
        !isCaregiverView &&
        (status == DoseStatus.takenOnTime || status == DoseStatus.takenLate);

    // Status colours
    Color statusPillBg;
    Color statusPillText = Colors.white;
    Color cardBorder;
    Color cardBg;
    Color iconColor;
    Color iconBg;
    String statusLabel;
    Color buttonColor;

    switch (status) {
      case DoseStatus.takenOnTime:
        statusPillBg = Colors.green.shade600;
        cardBorder = Colors.green.shade300;
        cardBg = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        iconBg = Colors.green.shade100;
        statusLabel = loc.takenOnTime;
        buttonColor = Colors.green.shade600;
        break;
      case DoseStatus.takenLate:
        statusPillBg = Colors.orange.shade700;
        cardBorder = Colors.orange.shade300;
        cardBg = Colors.orange.shade50;
        iconColor = Colors.orange.shade700;
        iconBg = Colors.orange.shade100;
        statusLabel = loc.takenLate;
        buttonColor = Colors.orange.shade700;
        break;
      case DoseStatus.missed:
        statusPillBg = Colors.red.shade600;
        cardBorder = Colors.red.shade300;
        cardBg = Colors.red.shade50;
        iconColor = Colors.red.shade700;
        iconBg = Colors.red.shade100;
        statusLabel = loc.missed;
        buttonColor = Colors.red.shade600;
        break;
      case DoseStatus.upcoming:
        if (isStrictlyPastDue) {
          statusPillBg = Colors.orange.shade700;
          cardBorder = Colors.orange.shade300;
          cardBg = Colors.orange.shade50;
          iconColor = Colors.orange.shade700;
          iconBg = Colors.orange.shade100;
          statusLabel = loc.pastDue;
          buttonColor = Colors.orange.shade700;
        } else if (shouldHighlight) {
          statusPillBg = const Color(0xFF1565C0);
          cardBorder = const Color(0xFF90CAF9);
          cardBg = const Color(0xFFE3F2FD);
          iconColor = const Color(0xFF1565C0);
          iconBg = const Color(0xFFBBDEFB);
          statusLabel = dose.scheduledDateTime.isAfter(now)
              ? loc.nextUp
              : loc.dueNow;
          buttonColor = const Color(0xFF1565C0);
        } else {
          statusPillBg = Colors.grey.shade500;
          cardBorder = Colors.grey.shade300;
          cardBg = Colors.grey.shade50;
          iconColor = Colors.grey.shade600;
          iconBg = Colors.grey.shade200;
          statusLabel = loc.upcoming;
          buttonColor = Colors.grey.shade600;
        }
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isCaregiverView ? 10 : 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDimmed ? 0.03 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isCaregiverView ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icon + name + status pill ──────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(isCaregiverView ? 10 : 13),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.medication_outlined,
                    color: iconColor,
                    size: isCaregiverView ? 26 : 32,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A2340),
                        ),
                      ),
                      if (med.doseForm != null ||
                          (med.doseStrength != null &&
                              med.doseStrength!.isNotEmpty)) ...[
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (med.doseForm != null) med.doseForm!,
                            if (med.doseStrength != null &&
                                med.doseStrength!.isNotEmpty)
                              med.doseStrength!,
                          ].join(' · '),
                          style: TextStyle(
                            fontSize: subFontSize - 1,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusPillBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: statusPillText,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: const Color(0xFFF0F1F3)),
            const SizedBox(height: 12),

            // ── Time chip ────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_outlined,
                        size: 17,
                        color: iconColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        time.format(context),
                        style: TextStyle(
                          fontSize: subFontSize,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                ),
                if (takenTime != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    '${loc.at} ${DateFormat('h:mm a').format(takenTime.toDate())}',
                    style: TextStyle(
                      fontSize: subFontSize - 2,
                      color: iconColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),

            // ── Frequency ────────────────────────────────────────
            if (med.frequency != null) ...[
              const SizedBox(height: 8),
              Text(
                '${loc.frequency}: ${med.frequency}',
                style: TextStyle(
                  fontSize: subFontSize - 1,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],

            // ── Notes ────────────────────────────────────────────
            if (med.notes != null && med.notes!.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                '${loc.notes}: ${med.notes}',
                style: TextStyle(
                  fontSize: subFontSize - 1,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],

            // ── Action buttons ───────────────────────────────────
            if (!isCaregiverView) ...[
              if (showTakenButton) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canMarkAsTaken ? onTakenPressed : null,
                    icon: const Icon(Icons.check_circle_outline, size: 26),
                    label: Text(
                      isStrictlyPastDue || status == DoseStatus.missed
                          ? loc.markAsTakenLate
                          : loc.markAsTaken,
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canMarkAsTaken
                          ? buttonColor
                          : Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonVPad),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: canMarkAsTaken ? 2 : 0,
                    ),
                  ),
                ),
              ],
              if (showUndoButton) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onUndoPressed,
                    icon: const Icon(Icons.undo, size: 24),
                    label: Text(
                      loc.undo,
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A2340),
                      side: BorderSide(
                        color: const Color(0xFF1A2340).withOpacity(0.3),
                        width: 1.5,
                      ),
                      padding: EdgeInsets.symmetric(vertical: buttonVPad - 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

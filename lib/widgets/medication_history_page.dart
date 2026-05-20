import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import '../models/medication.dart';
import '../services/medication_history_service.dart';
import '../services/medication_scheduler.dart';

// ─── Palette (matches rest of caregiver system) ──────────────────────────────
const _kTeal = Color(0xFF4DB6AC);
const _kNavy = Color(0xFF0D2D5D);
const _kBg = Color(0xFFF7F8FA);

/// Medication History Page — caregiver only.
class MedicationHistoryPage extends StatefulWidget {
  final String elderlyId;

  const MedicationHistoryPage({super.key, required this.elderlyId});

  @override
  State<MedicationHistoryPage> createState() => _MedicationHistoryPageState();
}

class _MedicationHistoryPageState extends State<MedicationHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final historyService = MedicationHistoryService();
    final loc = AppLocalizations.of(context)!;
    final elderlyId = widget.elderlyId;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 20,
                      color: _kTeal,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      loc.medicationHistory,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                      ),
                    ),
                  ),
                  // Clear all menu
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: _kNavy, size: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) async {
                      if (value == 'clear') {
                        final confirm = await _showClearConfirmDialog(context);
                        if (confirm == true) {
                          await historyService.clearHistory(elderlyId);
                          if (mounted) {
                            _showSnackFromKey(
                              loc.historyClearedToast,
                              Colors.red.shade600,
                            );
                          }
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_sweep,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              loc.clearAllHistoryMenu,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── List ─────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: historyService.getHistoryStream(elderlyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _kTeal),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _EmptyHistory();
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final docId = docs[index].id;
                      final rawData = Map<String, dynamic>.from(data);
                      // Normalize times: old docs store {hour,minute} maps; fromMap expects "HH:mm"
                      if (rawData['times'] is List) {
                        rawData['times'] = (rawData['times'] as List).map((t) {
                          if (t is Map) {
                            final h = (t['hour'] ?? 0).toString().padLeft(
                              2,
                              '0',
                            );
                            final m = (t['minute'] ?? 0).toString().padLeft(
                              2,
                              '0',
                            );
                            return '$h:$m';
                          }
                          return t;
                        }).toList();
                      }
                      final med = Medication.fromMap(rawData);
                      final reason = data['reason'] as String? ?? 'deleted';
                      final deletedAt = (data['deletedAt'] as Timestamp?)
                          ?.toDate();

                      return _HistoryCard(
                        medication: med,
                        reason: reason,
                        deletedAt: deletedAt,
                        onDelete: () async {
                          final confirm = await _showRemoveConfirmDialog(
                            context,
                            med.name,
                          );
                          if (confirm == true) {
                            await historyService.deleteHistoryEntry(
                              elderlyId,
                              docId,
                            );
                          }
                        },
                        onRecover: () async {
                          final scaffoldContext = context;
                          // Show smart recovery dialog with date + time review
                          final result = await _showRecoveryDialog(
                            context: context,
                            medication: med,
                            deletedAt: deletedAt,
                          );
                          if (result == null) return;

                          // Apply the new start date + updated times
                          await _recoverWithUpdates(
                            context: scaffoldContext,
                            historyService: historyService,
                            elderlyId: elderlyId,
                            historyDocId: docId,
                            originalMed: med,
                            newStartDate: result.newStartDate,
                            newTimes: result.newTimes,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  Future<bool?> _showClearConfirmDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          loc.clearAllHistory,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _kNavy,
          ),
        ),
        content: Text(
          loc.confirmClearHistory,
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              loc.clearAll,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showRemoveConfirmDialog(BuildContext context, String medName) {
    final loc = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          loc.removeFromHistory,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: _kNavy,
          ),
        ),
        content: Text(
          loc.confirmRemoveFromHistory(medName),
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              loc.remove,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Smart recovery dialog — shows original dates, date picker, time review.
  Future<_RecoveryResult?> _showRecoveryDialog({
    required BuildContext context,
    required Medication medication,
    required DateTime? deletedAt,
  }) {
    return showModalBottomSheet<_RecoveryResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _RecoverySheet(medication: medication, deletedAt: deletedAt),
    );
  }

  /// Actually recover: patch start/end dates and times then call service.
  Future<void> _recoverWithUpdates({
    required BuildContext context,
    required MedicationHistoryService historyService,
    required String elderlyId,
    required String historyDocId,
    required Medication originalMed,
    required DateTime newStartDate,
    required List<TimeOfDay> newTimes,
  }) async {
    try {
      // Patch the Firestore history doc with updated fields before recovering
      final historyDocRef = FirebaseFirestore.instance
          .collection('medications')
          .doc(elderlyId)
          .collection('history')
          .doc(historyDocId);

      final newCreatedAt = Timestamp.fromDate(newStartDate);

      // Recalculate endDate if original had a fixed duration
      Timestamp? newEndDate;
      if (originalMed.createdAt != null && originalMed.endDate != null) {
        final originalDuration = originalMed.endDate!.toDate().difference(
          originalMed.createdAt.toDate(),
        );
        newEndDate = Timestamp.fromDate(newStartDate.add(originalDuration));
      }

      // Encode updated times as "HH:mm" strings (matches Medication.fromMap)
      final timesEncoded = newTimes
          .map(
            (t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
          )
          .toList();

      await historyDocRef.update({
        'createdAt': newCreatedAt,
        if (newEndDate != null) 'endDate': newEndDate,
        'times': timesEncoded,
      });

      final recovered = await historyService.recoverFromHistory(
        elderlyId: elderlyId,
        historyDocId: historyDocId,
      );

      if (recovered != null) {
        await MedicationScheduler().scheduleAllMedications(elderlyId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.recoveredSuccessfully(recovered.name),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(
                                context,
                              )!.medicationAddedBackToList ??
                              'Added back to the active medications list.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          _showSnackFromKey(
            AppLocalizations.of(context)!.failedToRecover,
            Colors.red.shade600,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Recovery error: $e');
      if (mounted) {
        _showSnackFromKey(
          AppLocalizations.of(context)!.failedToRecover,
          Colors.red.shade600,
        );
      }
    }
  }

  void _showSnackFromKey(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Recovery result model
// ════════════════════════════════════════════════════════════════════════════
class _RecoveryResult {
  final DateTime newStartDate;
  final List<TimeOfDay> newTimes;
  _RecoveryResult({required this.newStartDate, required this.newTimes});
}

// ════════════════════════════════════════════════════════════════════════════
// Smart Recovery Bottom Sheet
// ════════════════════════════════════════════════════════════════════════════
class _RecoverySheet extends StatefulWidget {
  final Medication medication;
  final DateTime? deletedAt;

  const _RecoverySheet({required this.medication, required this.deletedAt});

  @override
  State<_RecoverySheet> createState() => _RecoverySheetState();
}

class _RecoverySheetState extends State<_RecoverySheet> {
  late DateTime _selectedDate;
  late List<TimeOfDay> _times;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _times = List<TimeOfDay>.from(widget.medication.times);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kTeal,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _editTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _kTeal,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _times[index] = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final deletedStr = widget.deletedAt != null
        ? DateFormat('MMM d, yyyy').format(widget.deletedAt!)
        : loc.unknownDate;
    final originalStartStr = DateFormat(
      'MMM d, yyyy',
    ).format(widget.medication.createdAt.toDate());
    final selectedDateStr = DateFormat(
      'EEE, MMM d, yyyy',
    ).format(_selectedDate);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  // ── Title ────────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _kTeal.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.restore_rounded,
                          color: _kTeal,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.recoverMedication,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                              ),
                            ),
                            Text(
                              widget.medication.name,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _kTeal,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Info strip ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _infoRow(
                          Icons.calendar_today_outlined,
                          Colors.blue.shade700,
                          loc.summaryStartDate,
                          originalStartStr,
                        ),
                        const SizedBox(height: 8),
                        _infoRow(
                          Icons.delete_outline_rounded,
                          Colors.red.shade600,
                          loc.deleted,
                          deletedStr,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── New start date ───────────────────────────────────
                  _sectionLabel(
                    loc.summaryStartDate + ' (${loc.newLabel ?? "New"})',
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kTeal, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: _kTeal,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedDateStr,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _kNavy,
                              ),
                            ),
                          ),
                          Text(
                            loc.change ?? 'Change',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _kTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Times review ─────────────────────────────────────
                  _sectionLabel(
                    loc.summaryTimes + ' (${loc.reviewLabel ?? "Review"})',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.reviewTimesHint ??
                        'Tap a time to adjust it for the new schedule.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_times.isEmpty)
                    Text(
                      loc.na,
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 13,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_times.length, (i) {
                        final t = _times[i];
                        return GestureDetector(
                          onTap: () => _editTime(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: _kTeal.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _kTeal.withOpacity(0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: _kTeal,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  t.format(context),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kNavy,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 12,
                                  color: _kTeal,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),

                  const SizedBox(height: 28),

                  // ── Action buttons ───────────────────────────────────
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(
                      context,
                      _RecoveryResult(
                        newStartDate: _selectedDate,
                        newTimes: _times,
                      ),
                    ),
                    icon: const Icon(Icons.restore_rounded, size: 18),
                    label: Text(
                      loc.recoverMedicationButton,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kTeal,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: BorderSide(color: Colors.grey.shade300),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      loc.cancel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2340),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF6B7280),
        letterSpacing: 0.3,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// History Card
// ════════════════════════════════════════════════════════════════════════════
class _HistoryCard extends StatelessWidget {
  final Medication medication;
  final String reason;
  final DateTime? deletedAt;
  final VoidCallback onDelete;
  final VoidCallback onRecover;

  const _HistoryCard({
    required this.medication,
    required this.reason,
    this.deletedAt,
    required this.onDelete,
    required this.onRecover,
  });

  Color _accentColor() {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF4DB6AC),
      const Color(0xFF7E57C2),
      const Color(0xFF1565C0),
      const Color(0xFFFF8F00),
      const Color(0xFFE91E8C),
    ];
    return colors[medication.name.hashCode.abs() % colors.length];
  }

  String _translateFreq(String? freq, AppLocalizations loc) {
    switch (freq) {
      case 'Once a day':
        return loc.freqOnce;
      case 'Twice a day':
        return loc.freqTwice;
      case 'Three times a day':
        return loc.freqThree;
      case 'Four times a day':
        return loc.freqFour;
      case 'Custom':
        return loc.freqCustom;
      default:
        return freq ?? loc.na;
    }
  }

  String _translateDay(String day, AppLocalizations loc) {
    switch (day) {
      case 'Every day':
        return loc.everyDay;
      case 'Sunday':
        return loc.daySunday;
      case 'Monday':
        return loc.dayMonday;
      case 'Tuesday':
        return loc.dayTuesday;
      case 'Wednesday':
        return loc.dayWednesday;
      case 'Thursday':
        return loc.dayThursday;
      case 'Friday':
        return loc.dayFriday;
      case 'Saturday':
        return loc.daySaturday;
      default:
        return day;
    }
  }

  String _translateForm(String? form, AppLocalizations loc) {
    switch (form) {
      case 'Capsule':
        return loc.formCapsule;
      case 'Syrup':
        return loc.formSyrup;
      case 'Cream/Ointment':
        return loc.formCream;
      case 'Eye Drops':
        return loc.formEyeDrops;
      case 'Ear Drops':
        return loc.formEarDrops;
      case 'Nasal Spray':
        return loc.formNasal;
      case 'Injection':
        return loc.formInjection;
      default:
        return form ?? loc.formOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final accent = _accentColor();
    final isExpired = reason == 'expired';
    final reasonColor = isExpired
        ? Colors.orange.shade700
        : Colors.red.shade600;
    final reasonLabel = isExpired ? loc.expired : loc.deleted;
    final dateStr = deletedAt != null
        ? DateFormat('MMM d, yyyy · h:mm a').format(deletedAt!)
        : loc.unknownDate;
    final timeString = medication.times
        .map((t) => t.format(context))
        .join('  ·  ');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar
              Container(width: 4, color: reasonColor),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row ───────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Med icon avatar
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.medication_rounded,
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medication.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6B7280),
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: Color(0xFF9CA3AF),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Reason badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: reasonColor.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isExpired
                                            ? Icons.timer_off_outlined
                                            : Icons.delete_outline_rounded,
                                        size: 11,
                                        color: reasonColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        reasonLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: reasonColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Delete (×) button
                          GestureDetector(
                            onTap: onDelete,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),
                      Divider(height: 1, color: Colors.grey.shade100),
                      const SizedBox(height: 10),

                      // ── Detail rows ───────────────────────────────
                      _row(
                        loc.frequency,
                        _translateFreq(medication.frequency, loc),
                      ),
                      if (medication.doseForm != null ||
                          (medication.doseStrength?.isNotEmpty ?? false))
                        _row(
                          loc.dose,
                          [
                            if (medication.doseForm != null)
                              _translateForm(medication.doseForm, loc),
                            if (medication.doseStrength?.isNotEmpty ?? false)
                              medication.doseStrength!,
                          ].join(' · '),
                        ),
                      _row(
                        loc.days,
                        medication.days
                            .map((d) => _translateDay(d, loc))
                            .join(', '),
                      ),
                      _row(
                        loc.times,
                        timeString.isNotEmpty ? timeString : loc.na,
                      ),
                      if (medication.endDate != null)
                        _row(
                          loc.endDate,
                          DateFormat(
                            'MMM d, yyyy',
                          ).format(medication.endDate!.toDate()),
                        ),
                      if (medication.notes?.isNotEmpty ?? false)
                        _row(loc.notes, medication.notes!),

                      const SizedBox(height: 12),

                      // ── Recover button ────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onRecover,
                          icon: const Icon(Icons.restore_rounded, size: 16),
                          label: Text(
                            loc.recoverMedicationButton,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ── Date footer ───────────────────────────────
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${isExpired ? loc.expired : loc.deleted} · $dateStr',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Empty state
// ════════════════════════════════════════════════════════════════════════════
class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kTeal.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.history_rounded, size: 52, color: _kTeal),
          ),
          const SizedBox(height: 20),
          Text(
            loc.noMedicationHistory,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              loc.noMedicationHistoryDesc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            ),
          ),
        ],
      ),
    );
  }
}

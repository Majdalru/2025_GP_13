import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import '../models/medication.dart';
import '../services/medication_history_service.dart';
import '../services/medication_scheduler.dart';

/// Medication History Page — shows deleted and expired medications.
/// Works for both caregiver and elderly views.
class MedicationHistoryPage extends StatelessWidget {
  final String elderlyId;
  final bool isElderlyView;

  const MedicationHistoryPage({
    super.key,
    required this.elderlyId,
    this.isElderlyView = false,
  });

  @override
  Widget build(BuildContext context) {
    final historyService = MedicationHistoryService();

    return Scaffold(
      backgroundColor: isElderlyView ? const Color(0xFFF5F5F5) : null,
      appBar: AppBar(
        toolbarHeight: isElderlyView ? 110 : 90,
        backgroundColor: isElderlyView
            ? const Color(0xFF1B3A52)
            : const Color.fromRGBO(12, 45, 93, 1),
        title: Text(AppLocalizations.of(context)!.medicationHistory),
        titleTextStyle: TextStyle(
          fontSize: isElderlyView ? 32 : 24,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: isElderlyView ? 42 : 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: isElderlyView ? 32 : 24,
            ),
            onSelected: (value) async {
              if (value == 'clear') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        isElderlyView ? 20 : 12,
                      ),
                    ),
                    title: Text(
                      AppLocalizations.of(context)!.clearAllHistory,
                      style: TextStyle(
                        fontSize: isElderlyView ? 26 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      AppLocalizations.of(context)!.confirmClearHistory,
                      style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          AppLocalizations.of(context)!.cancel,
                          style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          AppLocalizations.of(context)!.clearAll,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: isElderlyView ? 20 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await historyService.clearHistory(elderlyId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)!.historyClearedToast,
                        ),
                      ),
                    );
                  }
                }
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.clearAllHistoryMenu,
                      style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: historyService.getHistoryStream(elderlyId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: isElderlyView ? 80 : 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noMedicationHistory,
                    style: TextStyle(
                      fontSize: isElderlyView ? 24 : 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.noMedicationHistoryDesc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isElderlyView ? 18 : 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(isElderlyView ? 20 : 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final docId = docs[index].id;
              final med = Medication.fromMap(data);
              final reason = data['reason'] as String? ?? 'deleted';
              final deletedAt = (data['deletedAt'] as Timestamp?)?.toDate();

              return _HistoryCard(
                medication: med,
                reason: reason,
                deletedAt: deletedAt,
                isElderlyView: isElderlyView,
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          isElderlyView ? 20 : 12,
                        ),
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.removeFromHistory,
                        style: TextStyle(
                          fontSize: isElderlyView ? 24 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        AppLocalizations.of(
                          context,
                        )!.confirmRemoveFromHistory(med.name),
                        style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            AppLocalizations.of(context)!.remove,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: isElderlyView ? 20 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await historyService.deleteHistoryEntry(elderlyId, docId);
                  }
                },
                onRecover: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          isElderlyView ? 20 : 12,
                        ),
                      ),
                      title: Text(
                        AppLocalizations.of(context)!.recoverMedication,
                        style: TextStyle(
                          fontSize: isElderlyView ? 24 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        AppLocalizations.of(
                          context,
                        )!.confirmRecoverMedication(med.name),
                        style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            AppLocalizations.of(context)!.recover,
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: isElderlyView ? 20 : 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final recovered = await historyService.recoverFromHistory(
                      elderlyId: elderlyId,
                      historyDocId: docId,
                    );
                    if (recovered != null) {
                      // Reschedule notifications
                      await MedicationScheduler().scheduleAllMedications(
                        elderlyId,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.recoveredSuccessfully(recovered.name),
                                    style: TextStyle(
                                      fontSize: isElderlyView ? 20 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)!.failedToRecover,
                              style: TextStyle(
                                fontSize: isElderlyView ? 20 : 14,
                              ),
                            ),
                            backgroundColor: Colors.red.shade600,
                          ),
                        );
                      }
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Medication medication;
  final String reason;
  final DateTime? deletedAt;
  final bool isElderlyView;
  final VoidCallback onDelete;
  final VoidCallback onRecover;

  const _HistoryCard({
    required this.medication,
    required this.reason,
    this.deletedAt,
    required this.isElderlyView,
    required this.onDelete,
    required this.onRecover,
  });
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
    final isExpired = reason == 'expired';
    final reasonColor = isExpired
        ? Colors.orange.shade700
        : Colors.red.shade600;
    final reasonIcon = isExpired ? Icons.timer_off : Icons.delete_outline;
    final reasonLabel = isExpired
        ? AppLocalizations.of(context)!.expired
        : AppLocalizations.of(context)!.deleted;
    final dateStr = deletedAt != null
        ? DateFormat('MMM d, yyyy – h:mm a').format(deletedAt!)
        : AppLocalizations.of(context)!.unknownDate;

    final timeString = medication.times
        .map((t) => t.format(context))
        .join(', ');

    final double fontSize = isElderlyView ? 22.0 : 16.0;
    final double titleSize = isElderlyView ? 26.0 : 20.0;
    final double smallSize = isElderlyView ? 18.0 : 14.0;

    return Card(
      elevation: isElderlyView ? 4 : 2,
      margin: EdgeInsets.only(bottom: isElderlyView ? 20 : 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isElderlyView ? 20 : 12),
        side: BorderSide(color: reasonColor.withOpacity(0.3), width: 1.5),
      ),
      child: Padding(
        padding: EdgeInsets.all(isElderlyView ? 20.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: name + reason badge + delete button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.medication,
                  color: Colors.grey.shade500,
                  size: isElderlyView ? 36 : 24,
                ),
                SizedBox(width: isElderlyView ? 14 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Reason badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: reasonColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: reasonColor.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              reasonIcon,
                              size: smallSize,
                              color: reasonColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              reasonLabel,
                              style: TextStyle(
                                fontSize: smallSize,
                                fontWeight: FontWeight.w600,
                                color: reasonColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Colors.grey.shade400,
                    size: isElderlyView ? 28 : 22,
                  ),
                  onPressed: onDelete,
                  tooltip: loc.removeFromHistory,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details
            Container(
              padding: EdgeInsets.all(isElderlyView ? 16.0 : 12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow(
                    loc.frequency,
                    _translateFreq(medication.frequency, loc),
                    fontSize,
                  ),
                  const SizedBox(height: 4),
                  if (medication.doseForm != null ||
                      (medication.doseStrength != null &&
                          medication.doseStrength!.isNotEmpty)) ...[
                    _detailRow(
                      loc.dose,
                      [
                        if (medication.doseForm != null)
                          _translateForm(medication.doseForm, loc),
                        if (medication.doseStrength != null &&
                            medication.doseStrength!.isNotEmpty)
                          medication.doseStrength!,
                      ].join(' — '),
                      fontSize,
                    ),
                    const SizedBox(height: 4),
                  ],
                  _detailRow(
                    loc.days,
                    medication.days
                        .map((d) => _translateDay(d, loc))
                        .join(', '),
                    fontSize,
                  ),
                  const SizedBox(height: 4),
                  _detailRow(
                    loc.times,
                    timeString.isNotEmpty ? timeString : loc.na,
                    fontSize,
                  ),
                  if (medication.endDate != null) ...[
                    const SizedBox(height: 4),
                    _detailRow(
                      loc.endDate,
                      DateFormat(
                        'MMM d, yyyy',
                      ).format(medication.endDate!.toDate()),
                      fontSize,
                    ),
                  ],
                  if (medication.notes != null &&
                      medication.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _detailRow(loc.notes, medication.notes!, fontSize),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Recover button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onRecover,
                icon: Icon(
                  Icons.restore,
                  size: isElderlyView ? 26 : 20,
                  color: Colors.green.shade700,
                ),
                label: Text(
                  AppLocalizations.of(context)!.recoverMedicationButton,
                  style: TextStyle(
                    fontSize: isElderlyView ? 20 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: isElderlyView ? 14 : 10,
                  ),
                  side: BorderSide(color: Colors.green.shade400, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      isElderlyView ? 14 : 10,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Date footer
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: smallSize,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.actionOnDate(reasonLabel, dateStr),
                  style: TextStyle(
                    fontSize: smallSize,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, double fontSize) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: fontSize - 2, color: Colors.grey.shade700),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

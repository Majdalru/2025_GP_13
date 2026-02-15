import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../services/medication_history_service.dart';

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
        title: const Text('Medication History'),
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
                      'Clear All History?',
                      style: TextStyle(
                        fontSize: isElderlyView ? 26 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    content: Text(
                      'This will permanently remove all medication history records.',
                      style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          'Clear All',
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
                      const SnackBar(content: Text('History cleared')),
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
                      'Clear All History',
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
                    'No medication history',
                    style: TextStyle(
                      fontSize: isElderlyView ? 24 : 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Deleted and expired medications\nwill appear here',
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
                        'Remove from History?',
                        style: TextStyle(
                          fontSize: isElderlyView ? 24 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        'Remove "${med.name}" from history?',
                        style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontSize: isElderlyView ? 20 : 16),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            'Remove',
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

  const _HistoryCard({
    required this.medication,
    required this.reason,
    this.deletedAt,
    required this.isElderlyView,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpired = reason == 'expired';
    final reasonColor = isExpired
        ? Colors.orange.shade700
        : Colors.red.shade600;
    final reasonIcon = isExpired ? Icons.timer_off : Icons.delete_outline;
    final reasonLabel = isExpired ? 'Expired' : 'Deleted';
    final dateStr = deletedAt != null
        ? DateFormat('MMM d, yyyy – h:mm a').format(deletedAt!)
        : 'Unknown date';

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
                  tooltip: 'Remove from history',
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
                    'Frequency',
                    medication.frequency ?? 'N/A',
                    fontSize,
                  ),
                  const SizedBox(height: 4),
                  _detailRow('Days', medication.days.join(', '), fontSize),
                  const SizedBox(height: 4),
                  _detailRow(
                    'Times',
                    timeString.isNotEmpty ? timeString : 'N/A',
                    fontSize,
                  ),
                  if (medication.endDate != null) ...[
                    const SizedBox(height: 4),
                    _detailRow(
                      'End Date',
                      DateFormat(
                        'MMM d, yyyy',
                      ).format(medication.endDate!.toDate()),
                      fontSize,
                    ),
                  ],
                  if (medication.notes != null &&
                      medication.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _detailRow('Notes', medication.notes!, fontSize),
                  ],
                ],
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
                  '$reasonLabel on $dateStr',
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

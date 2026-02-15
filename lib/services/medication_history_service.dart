import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/medication.dart';

/// Service to manage medication history (deleted + expired medications).
/// Stores history in: medications/{elderlyId}/history/{docId}
class MedicationHistoryService {
  static final MedicationHistoryService _instance =
      MedicationHistoryService._internal();
  factory MedicationHistoryService() => _instance;
  MedicationHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save a medication to history when it's deleted or expires.
  /// [reason] is either 'deleted' or 'expired'.
  Future<void> saveToHistory({
    required String elderlyId,
    required Medication medication,
    required String reason,
    String? deletedBy,
  }) async {
    try {
      final historyRef = _firestore
          .collection('medications')
          .doc(elderlyId)
          .collection('history');

      await historyRef.add({
        ...medication.toMap(),
        'reason': reason, // 'deleted' | 'expired'
        'deletedAt': Timestamp.now(),
        'deletedBy': deletedBy,
      });

      debugPrint(
        '📋 Saved ${medication.name} to history (reason: $reason) for $elderlyId',
      );
    } catch (e) {
      debugPrint('❌ Error saving medication to history: $e');
    }
  }

  /// Save multiple expired medications to history at once.
  Future<void> saveBatchToHistory({
    required String elderlyId,
    required List<Medication> medications,
    required String reason,
  }) async {
    if (medications.isEmpty) return;

    try {
      final historyRef = _firestore
          .collection('medications')
          .doc(elderlyId)
          .collection('history');

      final batch = _firestore.batch();
      for (final med in medications) {
        final docRef = historyRef.doc();
        batch.set(docRef, {
          ...med.toMap(),
          'reason': reason,
          'deletedAt': Timestamp.now(),
          'deletedBy': null,
        });
      }
      await batch.commit();

      debugPrint(
        '📋 Saved ${medications.length} medications to history (reason: $reason) for $elderlyId',
      );
    } catch (e) {
      debugPrint('❌ Error saving batch to history: $e');
    }
  }

  /// Get history stream for display, ordered by deletedAt descending.
  Stream<QuerySnapshot<Map<String, dynamic>>> getHistoryStream(
    String elderlyId,
  ) {
    return _firestore
        .collection('medications')
        .doc(elderlyId)
        .collection('history')
        .orderBy('deletedAt', descending: true)
        .snapshots();
  }

  /// Clear all history for an elderly user.
  Future<void> clearHistory(String elderlyId) async {
    try {
      final historyRef = _firestore
          .collection('medications')
          .doc(elderlyId)
          .collection('history');

      final snapshot = await historyRef.get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('🗑️ Cleared all history for $elderlyId');
    } catch (e) {
      debugPrint('❌ Error clearing history: $e');
    }
  }

  /// Delete a single history entry.
  Future<void> deleteHistoryEntry(String elderlyId, String historyDocId) async {
    try {
      await _firestore
          .collection('medications')
          .doc(elderlyId)
          .collection('history')
          .doc(historyDocId)
          .delete();

      debugPrint('🗑️ Deleted history entry $historyDocId');
    } catch (e) {
      debugPrint('❌ Error deleting history entry: $e');
    }
  }
}

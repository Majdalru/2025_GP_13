import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/medication.dart';
import 'notification_service.dart';
import 'medication_history_service.dart';

class MedicationScheduler {
  static final MedicationScheduler _instance = MedicationScheduler._internal();
  factory MedicationScheduler() => _instance;
  MedicationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// جدولة جميع أدوية المستخدم الكبير
  Future<void> scheduleAllMedications(String elderlyId) async {
    try {
      await _notificationService.cancelAllNotifications();
      debugPrint(
        '🗑️ Cancelled all notifications before rescheduling for $elderlyId',
      );

      final docSnapshot = await _firestore
          .collection('medications')
          .doc(elderlyId)
          .get();

      if (!docSnapshot.exists || docSnapshot.data()?['medsList'] == null) {
        debugPrint(
          '⚠️ No medications found or empty list for elderly: $elderlyId',
        );
        return;
      }

      final data = docSnapshot.data();
      final medsList =
          (data?['medsList'] as List?)
              ?.map(
                (medMap) => Medication.fromMap(medMap as Map<String, dynamic>),
              )
              .toList() ??
          [];

      // ═══════════════════════════════════════════════
      // ✅ NEW: Remove expired medications from Firestore
      // ═══════════════════════════════════════════════
      final now = DateTime.now();
      final List<Medication> expiredMeds = [];
      final List<Medication> activeMeds = [];

      for (final med in medsList) {
        if (med.endDate != null && med.endDate!.toDate().isBefore(now)) {
          expiredMeds.add(med);
        } else {
          activeMeds.add(med);
        }
      }

      if (expiredMeds.isNotEmpty) {
        debugPrint(
          '🧹 Found ${expiredMeds.length} expired medication(s) to remove:',
        );
        for (final expired in expiredMeds) {
          debugPrint(
            '   - ${expired.name} (ended ${DateFormat('MMM d, yyyy').format(expired.endDate!.toDate())})',
          );
        }

        // ✅ Save expired meds to history before removing
        await MedicationHistoryService().saveBatchToHistory(
          elderlyId: elderlyId,
          medications: expiredMeds,
          reason: 'expired',
        );

        // Update Firestore: replace medsList with only active meds
        final docRef = _firestore.collection('medications').doc(elderlyId);
        await docRef.update({
          'medsList': activeMeds.map((m) => m.toMap()).toList(),
        });

        debugPrint(
          '✅ Removed ${expiredMeds.length} expired medication(s) from Firestore',
        );
      }

      int scheduledCount = 0;
      for (final med in activeMeds) {
        await _scheduleMedication(elderlyId, med);
        // Schedule refill reminder if enabled and end date exists
        if (med.refillReminder && med.endDate != null) {
          await _scheduleRefillReminder(elderlyId, med);
        }
        scheduledCount++;
      }

      debugPrint(
        '✅ Processed scheduling for $scheduledCount medications for $elderlyId',
      );

      final pending = await _notificationService.getPendingNotifications();
      debugPrint(
        'ℹ️ Pending notifications count after rescheduling: ${pending.length}',
      );
    } catch (e) {
      debugPrint('❌ Error scheduling medications for $elderlyId: $e');
    }
  }

  /// جدولة دواء واحد مع أوقاته المتعددة
  Future<void> _scheduleMedication(String elderlyId, Medication med) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    Map<String, dynamic> logData = {};
    try {
      final logDoc = await _firestore
          .collection('medication_log')
          .doc(elderlyId)
          .collection('daily_log')
          .doc(todayKey)
          .get();
      if (logDoc.exists) {
        logData = logDoc.data() ?? {};
      }
    } catch (e) {
      debugPrint(
        'ℹ️ Could not fetch medication log for $elderlyId/$todayKey: $e',
      );
    }

    // ✅ تعديل: زيادة عدد الأيام لـ 14 يوم
    final daysToSchedule = _getDaysToSchedule(med.days, today, med.endDate);

    debugPrint('🗓️ Scheduling ${med.name} for ${daysToSchedule.length} days');

    for (final day in daysToSchedule) {
      for (int i = 0; i < med.times.length; i++) {
        final time = med.times[i];
        final scheduledTime = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        );

        if (scheduledTime.isBefore(now.subtract(const Duration(minutes: 11)))) {
          continue;
        }

        final doseLogKey = '${med.id}_$i';
        final doseLog = logData[doseLogKey] as Map<String, dynamic>?;
        final currentStatusString = doseLog?['status'] as String?;
        bool alreadyTaken =
            currentStatusString == 'taken_on_time' ||
            currentStatusString == 'taken_late';

        if (DateUtils.isSameDay(day, now) && alreadyTaken) {
          String formattedTime =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          debugPrint(
            '🚫 Skipping notifications for ${med.name} at $formattedTime (Day: ${DateFormat('yyyy-MM-dd').format(day)}) - Already taken according to log.',
          );
          continue;
        }

        // --- Schedule Notifications ---

        // ✅ تعديل: إضافة scheduledTime للـ ID
        final notifId1 = _generateNotificationId(
          elderlyId,
          med.id,
          i,
          0,
          scheduledTime,
        );
        if (scheduledTime.isAfter(now)) {
          await _notificationService.scheduleNotification(
            id: notifId1,
            title: '💊 Medication Time',
            body: "It's time to take your ${med.name}.",
            scheduledTime: scheduledTime,
            payload: 'med:$elderlyId:${med.id}:$i:0',
          );
        }

        // ✅ تعديل: إضافة scheduledTime للـ ID
        final reminderTime = scheduledTime.add(const Duration(minutes: 5));
        final notifId2 = _generateNotificationId(
          elderlyId,
          med.id,
          i,
          1,
          scheduledTime,
        );
        if (reminderTime.isAfter(now)) {
          await _notificationService.scheduleNotification(
            id: notifId2,
            title: '⏰ Medication Reminder',
            body: "Don't forget to take your ${med.name}.",
            scheduledTime: reminderTime,
            payload: 'reminder:$elderlyId:${med.id}:$i:1',
          );
        }

        // ✅ تعديل: إضافة scheduledTime للـ ID
        final missedAlertTime = scheduledTime.add(const Duration(minutes: 10));
        final notifId3 = _generateNotificationId(
          elderlyId,
          med.id,
          i,
          2,
          scheduledTime,
        );
        if (missedAlertTime.isAfter(now)) {
          await notifyCaregiversMissed(
            elderlyId: elderlyId,
            medication: med,
            scheduledTime: scheduledTime,
            timeIndex: i,
            notificationId: notifId3,
          );
        }
      }
    }
  }

  /// جدولة تنبيه لجميع caregivers المرتبطين بكبير السن - **يستخدم للتنبيه عند التفويت**
  Future<void> notifyCaregiversMissed({
    required String elderlyId,
    required Medication medication,
    required DateTime scheduledTime,
    required int timeIndex,
    required int notificationId,
  }) async {
    try {
      final elderlyDoc = await _firestore
          .collection('users')
          .doc(elderlyId)
          .get();
      final elderlyData = elderlyDoc.data();
      final elderlyName = [
        elderlyData?['firstName'] ?? '',
        elderlyData?['lastName'] ?? '',
      ].where((s) => s.toString().isNotEmpty).join(' ');
      final displayElderlyName = elderlyName.isNotEmpty
          ? elderlyName
          : "The elderly person";

      final caregiversSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('elderlyIds', arrayContains: elderlyId)
          .get();

      if (caregiversSnapshot.docs.isEmpty) {
        debugPrint(
          'ℹ️ [Missed Notify] No caregivers found linked to $elderlyId to notify.',
        );
        return;
      }

      debugPrint(
        '👥 [Missed Notify] Found ${caregiversSnapshot.docs.length} caregivers for $elderlyId',
      );

      final String body =
          '$displayElderlyName missed their ${medication.name} dose scheduled for ${DateFormat('h:mm a').format(scheduledTime)}!';
      final DateTime notificationTime = scheduledTime.add(
        const Duration(minutes: 10),
      );

      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.scheduleNotification(
          id: notificationId,
          title: '🚨 Medication Missed Alert',
          body: body,
          scheduledTime: notificationTime,
          payload:
              'caregiver_alert_missed:$elderlyId:${medication.id}:$timeIndex:2',
        );
      }
    } catch (e) {
      debugPrint('❌ Error in notifyCaregiversMissed for $elderlyId: $e');
    }
  }

  /// إرسال تنبيه فوري لـ caregivers عند أخذ الدواء متأخراً (Case 4)
  Future<void> notifyCaregiversTakenLate({
    required String elderlyId,
    required Medication medication,
    required DateTime takenAt,
    required DateTime scheduledTime,
  }) async {
    try {
      final elderlyDoc = await _firestore
          .collection('users')
          .doc(elderlyId)
          .get();
      final elderlyData = elderlyDoc.data();
      final elderlyName = [
        elderlyData?['firstName'] ?? '',
        elderlyData?['lastName'] ?? '',
      ].where((s) => s.toString().isNotEmpty).join(' ');
      final displayElderlyName = elderlyName.isNotEmpty
          ? elderlyName
          : "The elderly person";

      final caregiversSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('elderlyIds', arrayContains: elderlyId)
          .get();

      if (caregiversSnapshot.docs.isEmpty) {
        debugPrint(
          'ℹ️ [Late Notify] No caregivers found linked to $elderlyId to notify.',
        );
        return;
      }

      debugPrint(
        '👥 [Late Notify] Found ${caregiversSnapshot.docs.length} caregivers for $elderlyId',
      );

      final Duration difference = takenAt.difference(scheduledTime);
      final String lateDuration = _formatDuration(difference);

      final String body =
          '$displayElderlyName took their ${medication.name} dose late (scheduled for ${DateFormat('h:mm a').format(scheduledTime)}, taken at ${DateFormat('h:mm a').format(takenAt)} - $lateDuration late).';

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final immediateNotificationId =
          '${elderlyId}-${medication.id}-late-$uniqueSuffix'.hashCode.abs() %
          2147483647;

      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.showImmediateNotification(
          id: immediateNotificationId,
          title: '⏰ Medication Taken Late',
          body: body,
          payload: 'caregiver_alert_late:$elderlyId:${medication.id}',
        );
        debugPrint(
          '🔔 Sent LATE notification #${immediateNotificationId} to caregiver ${caregiverDoc.id}',
        );
      }
    } catch (e) {
      debugPrint(
        '❌ Error sending caregiver LATE notification for $elderlyId: $e',
      );
    }
  }

  /// إرسال تنبيه فوري لـ caregivers عند أخذ الدواء في الوقت المحدد
  Future<void> notifyCaregiversTakenOnTime({
    required String elderlyId,
    required Medication medication,
    required DateTime takenAt,
    required DateTime scheduledTime,
  }) async {
    try {
      final elderlyDoc = await _firestore
          .collection('users')
          .doc(elderlyId)
          .get();
      final elderlyData = elderlyDoc.data();
      final elderlyName = [
        elderlyData?['firstName'] ?? '',
        elderlyData?['lastName'] ?? '',
      ].where((s) => s.toString().isNotEmpty).join(' ');
      final displayElderlyName = elderlyName.isNotEmpty
          ? elderlyName
          : "The elderly person";

      final caregiversSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('elderlyIds', arrayContains: elderlyId)
          .get();

      if (caregiversSnapshot.docs.isEmpty) {
        debugPrint(
          'ℹ️ [On Time Notify] No caregivers found linked to $elderlyId to notify.',
        );
        return;
      }

      debugPrint(
        '👥 [On Time Notify] Found ${caregiversSnapshot.docs.length} caregivers for $elderlyId',
      );

      final String body =
          '$displayElderlyName took their ${medication.name} dose on time at ${DateFormat('h:mm a').format(takenAt)}.';

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final immediateNotificationId =
          '${elderlyId}-${medication.id}-onTime-$uniqueSuffix'.hashCode.abs() %
          2147483647;

      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.showImmediateNotification(
          id: immediateNotificationId,
          title: '✅ Medication Taken On Time',
          body: body,
          payload: 'caregiver_alert_onTime:$elderlyId:${medication.id}',
        );
        debugPrint(
          '🔔 Sent ON TIME notification #${immediateNotificationId} to caregiver ${caregiverDoc.id}',
        );
      }
    } catch (e) {
      debugPrint(
        '❌ Error sending caregiver ON TIME notification for $elderlyId: $e',
      );
    }
  }

  /// Schedule a 10:00 AM caregiver notification 3 days before medication ends
  Future<void> _scheduleRefillReminder(String elderlyId, Medication med) async {
    try {
      final endDate = med.endDate!.toDate();
      final reminderDate = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
      ).subtract(const Duration(days: 3));

      // Fire at 10:00 AM on the reminder date
      final scheduledTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        10,
        0,
      );

      final now = DateTime.now();
      if (scheduledTime.isBefore(now)) {
        debugPrint(
          '⏭️ Refill reminder for ${med.name} is in the past, skipping.',
        );
        return;
      }

      // Fetch caregiver(s) linked to this elderly user
      final caregiversSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('elderlyIds', arrayContains: elderlyId)
          .get();

      if (caregiversSnapshot.docs.isEmpty) {
        debugPrint('ℹ️ [Refill] No caregivers found for $elderlyId.');
        return;
      }

      // Generate a stable ID for this reminder
      final notifId = '$elderlyId-${med.id}-refill'.hashCode.abs() % 2147483647;

      await _notificationService.scheduleNotification(
        id: notifId,
        title: '💊 Medication Ending Soon',
        body: '${med.name} ends in 3 days. Please arrange a refill.',
        scheduledTime: scheduledTime,
        payload: 'refill:$elderlyId:${med.id}',
      );

      debugPrint(
        '🔔 Scheduled refill reminder #$notifId for ${med.name} at ${scheduledTime.toString()}',
      );
    } catch (e) {
      debugPrint('❌ Error scheduling refill reminder for ${med.name}: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${twoDigitMinutes}m";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m";
    } else {
      return "${duration.inSeconds}s";
    }
  }

  /// ✅ تعديل: إضافة parameter للتاريخ
  int _generateNotificationId(
    String elderlyId,
    String medicationId,
    int timeIndex,
    int type,
    DateTime scheduledDate, // ← التاريخ المضاف
  ) {
    final dateKey = DateFormat('yyyyMMdd').format(scheduledDate);
    final combined = '$elderlyId-$medicationId-$timeIndex-$type-$dateKey';
    return combined.hashCode.abs() % 2147483647;
  }

  /// ✅ تعديل: زيادة عدد الأيام من 7 إلى 14
  List<DateTime> _getDaysToSchedule(
    List<String> selectedDays,
    DateTime startDay,
    Timestamp? endDate, // ← NEW parameter
  ) {
    final today = DateTime(startDay.year, startDay.month, startDay.day);

    int maxDays = 14;
    if (endDate != null) {
      final endDateTime = endDate.toDate();
      final endDay = DateTime(
        endDateTime.year,
        endDateTime.month,
        endDateTime.day,
      );
      final daysUntilEnd = endDay.difference(today).inDays + 1; // inclusive
      if (daysUntilEnd <= 0) return []; // Already expired
      maxDays = daysUntilEnd.clamp(1, 14);
    }

    if (selectedDays.contains('Every day')) {
      return List.generate(14, (i) => today.add(Duration(days: i)));
    }

    const daysMap = {
      'Sunday': DateTime.sunday,
      'Monday': DateTime.monday,
      'Tuesday': DateTime.tuesday,
      'Wednesday': DateTime.wednesday,
      'Thursday': DateTime.thursday,
      'Friday': DateTime.friday,
      'Saturday': DateTime.saturday,
    };

    final targetWeekdays = selectedDays
        .map((day) => daysMap[day])
        .whereType<int>()
        .toSet();

    if (targetWeekdays.isEmpty) return [];

    final result = <DateTime>[];
    for (int i = 0; i < 14; i++) {
      // ← زيادة من 7 إلى 14
      final day = today.add(Duration(days: i));
      if (targetWeekdays.contains(day.weekday)) {
        result.add(day);
      }
    }

    debugPrint(
      '📅 Days to schedule for ${selectedDays.join(", ")}: ${result.length} days',
    );
    return result;
  }

  Future<void> cancelAllMedicationsForUser(String elderlyId) async {
    await _notificationService.cancelAllNotifications();
    debugPrint(
      '🗑️ Cancelled ALL pending notifications (triggered by user: $elderlyId)',
    );
  }

  Future<void> updateMedicationSchedule(String elderlyId) async {
    debugPrint('🔄 Rescheduling all medications for $elderlyId due to update.');
    await scheduleAllMedications(elderlyId);
  }

  Future<void> deleteMedicationSchedule(String elderlyId) async {
    debugPrint(
      '🔄 Rescheduling all medications for $elderlyId due to deletion.',
    );
    await scheduleAllMedications(elderlyId);
  }

  /// ✅ تعديل: إضافة parameter للتاريخ
  Future<void> markMedicationTaken(
    String elderlyId,
    String medicationId,
    int timeIndex,
    DateTime scheduledDate, // ← parameter جديد
  ) async {
    final notifId2 = _generateNotificationId(
      elderlyId,
      medicationId,
      timeIndex,
      1,
      scheduledDate, // ← استخدام التاريخ
    );
    final notifId3 = _generateNotificationId(
      elderlyId,
      medicationId,
      timeIndex,
      2,
      scheduledDate, // ← استخدام التاريخ
    );

    try {
      await _notificationService.cancelNotification(notifId2);
    } catch (e) {
      debugPrint('⚠️ Error cancelling notification #$notifId2: $e');
    }
    try {
      await _notificationService.cancelNotification(notifId3);
    } catch (e) {
      debugPrint('⚠️ Error cancelling notification #$notifId3: $e');
    }

    debugPrint(
      '✅ Processed cancellations for taken medication ($medicationId / index $timeIndex)',
    );
  }
}

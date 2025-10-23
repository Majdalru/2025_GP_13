import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
// ---> ADD THIS IMPORT <---
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// ---> END OF ADDITION <---

import '../models/medication.dart';
import 'notification_service.dart';

// Import DoseStatus if it's defined in todays_meds_tab.dart or define it here
// Assuming DoseStatus is defined elsewhere, like in models or a shared location

class MedicationScheduler {
  static final MedicationScheduler _instance = MedicationScheduler._internal();
  factory MedicationScheduler() => _instance;
  MedicationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance

  /// جدولة جميع أدوية المستخدم الكبير
  Future<void> scheduleAllMedications(String elderlyId) async {
    try {
      // It's safer to cancel *all* notifications and reschedule to avoid dangling ones
      await _notificationService.cancelAllNotifications();
      debugPrint(
        '🗑️ Cancelled all notifications before rescheduling for $elderlyId',
      );

      // جلب الأدوية من Firestore
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

      int scheduledCount = 0;
      // جدولة كل دواء
      for (final med in medsList) {
        await _scheduleMedication(elderlyId, med);
        scheduledCount++; // Increment count for each medication processed
      }

      debugPrint(
        '✅ Processed scheduling for $scheduledCount medications for $elderlyId',
      );

      // Optional: Log pending notifications to verify
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

    // Get today's log to check if already taken/missed
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
      // Proceed without log data, assuming nothing is taken/missed yet for scheduling
    }

    // Schedule for the next 7 days including today
    final daysToSchedule = _getDaysToSchedule(med.days, today);

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

        // Don't schedule notifications for times clearly in the past (more than 10 mins ago)
        if (scheduledTime.isBefore(now.subtract(const Duration(minutes: 11)))) {
          continue;
        }

        // Check log: If already taken or marked missed today, don't schedule notifications for this slot
        final doseLogKey = '${med.id}_$i'; // Key used in the log document
        final doseLog = logData[doseLogKey] as Map<String, dynamic>?;
        final currentStatusString = doseLog?['status'] as String?;
        bool alreadyTaken =
            currentStatusString == 'taken_on_time' ||
            currentStatusString == 'taken_late';

        if (DateUtils.isSameDay(day, now) && alreadyTaken) {
          // Use a placeholder context or find a way to get context if needed for format
          String formattedTime =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          debugPrint(
            '🚫 Skipping notifications for ${med.name} at $formattedTime (Day: ${DateFormat('yyyy-MM-dd').format(day)}) - Already taken according to log.',
          );
          continue; // Skip scheduling notifications if already taken today
        }

        // --- Schedule Notifications ---

        // Notification 1: On time reminder for Elderly
        final notifId1 = _generateNotificationId(elderlyId, med.id, i, 0);
        if (scheduledTime.isAfter(now)) {
          await _notificationService.scheduleNotification(
            id: notifId1,
            title: '💊 Medication Time',
            body: "It's time to take your ${med.name}.",
            scheduledTime: scheduledTime,
            payload: 'med:$elderlyId:${med.id}:$i:0',
          );
        }

        // Notification 2: 5 mins late reminder for Elderly
        final reminderTime = scheduledTime.add(const Duration(minutes: 5));
        final notifId2 = _generateNotificationId(elderlyId, med.id, i, 1);
        if (reminderTime.isAfter(now)) {
          await _notificationService.scheduleNotification(
            id: notifId2,
            title: '⏰ Medication Reminder',
            body: "Don't forget to take your ${med.name}.",
            scheduledTime: reminderTime,
            payload: 'reminder:$elderlyId:${med.id}:$i:1',
          );
        }

        // Notification 3: 10 mins late -> Notify Caregivers (Missed Alert)
        final missedAlertTime = scheduledTime.add(const Duration(minutes: 10));
        final notifId3 = _generateNotificationId(elderlyId, med.id, i, 2);
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
    required DateTime scheduledTime, // الوقت الأصلي للدواء
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
          id: notificationId, // Use the passed-in ID
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

  /// **NEW:** إرسال تنبيه فوري لـ caregivers عند أخذ الدواء متأخراً (Case 4)
  /// **UPDATED:** Added scheduledTime parameter
  Future<void> notifyCaregiversTakenLate({
    required String elderlyId,
    required Medication medication,
    required DateTime takenAt, // الوقت الفعلي للأخذ
    required DateTime scheduledTime, // الوقت المجدول الأصلي
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
      final String lateDuration = _formatDuration(
        difference,
      ); // Format the duration

      final String body =
          '$displayElderlyName took their ${medication.name} dose late (scheduled for ${DateFormat('h:mm a').format(scheduledTime)}, taken at ${DateFormat('h:mm a').format(takenAt)} - $lateDuration late).';

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final immediateNotificationId =
          '${elderlyId}-${medication.id}-late-$uniqueSuffix'.hashCode.abs() %
          2147483647;

      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.showImmediateNotification(
          id: immediateNotificationId,
          title: ' Medication Taken Late',
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

  /// **NEW:** إرسال تنبيه فوري لـ caregivers عند أخذ الدواء في الوقت المحدد
  Future<void> notifyCaregiversTakenOnTime({
    required String elderlyId,
    required Medication medication,
    required DateTime takenAt, // الوقت الفعلي للأخذ
    required DateTime scheduledTime, // الوقت المجدول الأصلي
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

  // Helper function to format Duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    // String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    if (duration.inHours > 0) {
      return "${duration.inHours}h ${twoDigitMinutes}m";
    } else if (duration.inMinutes > 0) {
      return "${duration.inMinutes}m";
    } else {
      return "${duration.inSeconds}s";
    }
  }

  /// توليد ID فريد للتنبيه
  int _generateNotificationId(
    String elderlyId,
    String medicationId,
    int timeIndex,
    int type,
  ) {
    final combined = '$elderlyId-$medicationId-$timeIndex-$type';
    return combined.hashCode.abs() % 2147483647;
  }

  /// تحديد الأيام القادمة للجدولة
  List<DateTime> _getDaysToSchedule(
    List<String> selectedDays,
    DateTime startDay,
  ) {
    final today = DateTime(startDay.year, startDay.month, startDay.day);

    if (selectedDays.contains('Every day')) {
      return List.generate(7, (i) => today.add(Duration(days: i)));
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
    for (int i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      if (targetWeekdays.contains(day.weekday)) {
        result.add(day);
      }
    }
    return result;
  }

  /// إلغاء جميع التنبيهات لمستخدم معين
  Future<void> cancelAllMedicationsForUser(String elderlyId) async {
    await _notificationService.cancelAllNotifications();
    debugPrint(
      '🗑️ Cancelled ALL pending notifications (triggered by user: $elderlyId)',
    );
  }

  /// تحديث جدولة دواء معين بعد التعديل
  Future<void> updateMedicationSchedule(String elderlyId) async {
    debugPrint('🔄 Rescheduling all medications for $elderlyId due to update.');
    await scheduleAllMedications(elderlyId);
  }

  /// حذف جدولة دواء معين
  Future<void> deleteMedicationSchedule(String elderlyId) async {
    debugPrint(
      '🔄 Rescheduling all medications for $elderlyId due to deletion.',
    );
    await scheduleAllMedications(elderlyId);
  }

  /// تسجيل أخذ الدواء (إلغاء التنبيهات التالية لهذا الوقت)
  Future<void> markMedicationTaken(
    String elderlyId,
    String medicationId,
    int timeIndex,
  ) async {
    final notifId2 = _generateNotificationId(
      elderlyId,
      medicationId,
      timeIndex,
      1,
    ); // 5 min reminder
    final notifId3 = _generateNotificationId(
      elderlyId,
      medicationId,
      timeIndex,
      2,
    ); // 10 min (missed) caregiver alert

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
} // End MedicationScheduler Class

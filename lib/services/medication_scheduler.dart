import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../models/medication.dart';
import 'notification_service.dart';

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

      int scheduledCount = 0;
      for (final med in medsList) {
        await _scheduleMedication(elderlyId, med);
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

        // Skip past schedules
        if (scheduledTime.isBefore(now.subtract(const Duration(minutes: 11)))) {
          continue;
        }

        // Check if already taken
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
            '🚫 Skipping notifications for ${med.name} at $formattedTime - Already taken.',
          );
          continue;
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
          debugPrint(
            '📅 Scheduled ON-TIME #$notifId1 for ${med.name} at ${DateFormat('HH:mm').format(scheduledTime)}',
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
          debugPrint(
            '📅 Scheduled 5-MIN #$notifId2 for ${med.name} at ${DateFormat('HH:mm').format(reminderTime)}',
          );
        }

        // NEW: Schedule immediate caregiver notification at medication time
        final notifId3 = _generateNotificationId(elderlyId, med.id, i, 2);
        if (scheduledTime.isAfter(now)) {
          await _notificationService.scheduleNotification(
            id: notifId3,
            title: '👀 Medication Due',
            body: "${med.name} is due now for the elderly person.",
            scheduledTime: scheduledTime,
            payload: 'caregiver_due:$elderlyId:${med.id}:$i:2',
          );
          debugPrint(
            '📅 Scheduled CAREGIVER DUE #$notifId3 for ${med.name} at ${DateFormat('HH:mm').format(scheduledTime)}',
          );
        }
      }
    }
  }

  /// **NEW:** إرسال تنبيه فوري لـ caregivers عند تفويت الدواء (يتم استدعاؤه من TodaysMedsTab)
  Future<void> notifyCaregiversMissedImmediately({
    required String elderlyId,
    required Medication medication,
    required DateTime scheduledTime,
    required int timeIndex,
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
          '$displayElderlyName missed their ${medication.name} dose scheduled for ${DateFormat('h:mm a').format(scheduledTime)}! Please check on them.';

      // Generate unique ID for immediate notification
      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final immediateNotificationId =
          '${elderlyId}-${medication.id}-missed-$uniqueSuffix'.hashCode.abs() %
          2147483647;

      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.showImmediateNotification(
          id: immediateNotificationId,
          title: '🚨 Medication Missed!',
          body: body,
          payload:
              'caregiver_alert_missed:$elderlyId:${medication.id}:$timeIndex',
        );
        debugPrint(
          '🔔 Sent IMMEDIATE MISSED notification to caregiver ${caregiverDoc.id}',
        );
      }
    } catch (e) {
      debugPrint(
        '❌ Error in notifyCaregiversMissedImmediately for $elderlyId: $e',
      );
    }
  }

  /// **NEW:** إرسال تنبيه فوري لـ caregivers عند أخذ الدواء متأخراً
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

      final String body =
          '$displayElderlyName took their ${medication.name} dose late at ${DateFormat('h:mm a').format(takenAt)} (was scheduled for ${DateFormat('h:mm a').format(scheduledTime)}).';

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final immediateNotificationId =
          '${elderlyId}-${medication.id}-late-$uniqueSuffix'.hashCode.abs() %
          2147483647;

      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.showImmediateNotification(
          id: immediateNotificationId,
          title: '⚠️ Medication Taken Late',
          body: body,
          payload: 'caregiver_alert_late:$elderlyId:${medication.id}',
        );
        debugPrint('🔔 Sent LATE notification to caregiver ${caregiverDoc.id}');
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
    required DateTime takenAt,
    required DateTime scheduledTime,
  }) async {
    try {
      final caregiversSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('elderlyIds', arrayContains: elderlyId)
          .get();

      if (caregiversSnapshot.docs.isEmpty) {
        return;
      }

      final String body =
          '${medication.name} was taken on time at ${DateFormat('h:mm a').format(takenAt)}.';

      final uniqueSuffix = DateTime.now().millisecondsSinceEpoch;
      final immediateNotificationId =
          '${elderlyId}-${medication.id}-ontime-$uniqueSuffix'.hashCode.abs() %
          2147483647;

      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.showImmediateNotification(
          id: immediateNotificationId,
          title: '✅ Medication Taken',
          body: body,
          payload: 'caregiver_alert_ontime:$elderlyId:${medication.id}',
        );
      }
      debugPrint('🔔 Sent ON-TIME notification to caregivers');
    } catch (e) {
      debugPrint(
        '❌ Error sending caregiver ON-TIME notification for $elderlyId: $e',
      );
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

  /// تسجيل أخذ الدواء (إلغاء التنبيهات التالية)
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
    );
    final notifId3 = _generateNotificationId(
      elderlyId,
      medicationId,
      timeIndex,
      2,
    );

    try {
      await _notificationService.cancelNotification(notifId2);
      debugPrint('🚫 Cancelled 5-min reminder #$notifId2');
    } catch (e) {
      debugPrint('⚠️ Error cancelling notification #$notifId2: $e');
    }
    try {
      await _notificationService.cancelNotification(notifId3);
      debugPrint('🚫 Cancelled caregiver due notification #$notifId3');
    } catch (e) {
      debugPrint('⚠️ Error cancelling notification #$notifId3: $e');
    }

    debugPrint(
      '✅ Processed cancellations for taken medication ($medicationId / index $timeIndex)',
    );
  }

  /// **NEW:** الحصول على جميع التنبيهات المجدولة (للتdebug)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationService.getPendingNotifications();
  }
}

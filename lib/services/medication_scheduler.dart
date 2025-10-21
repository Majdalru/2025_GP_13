import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/medication.dart';
import 'notification_service.dart';

class MedicationScheduler {
  static final MedicationScheduler _instance = MedicationScheduler._internal();
  factory MedicationScheduler() => _instance;
  MedicationScheduler._internal();

  final NotificationService _notificationService = NotificationService();

  /// جدولة جميع أدوية المستخدم الكبير
  Future<void> scheduleAllMedications(String elderlyId) async {
    try {
      // إلغاء جميع التنبيهات السابقة لهذا المستخدم
      await cancelAllMedicationsForUser(elderlyId);

      // جلب الأدوية من Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('medications')
          .doc(elderlyId)
          .get();

      if (!docSnapshot.exists) {
        debugPrint('⚠️ No medications found for elderly: $elderlyId');
        return;
      }

      final data = docSnapshot.data();
      final medsList = (data?['medsList'] as List?)
          ?.map((medMap) => Medication.fromMap(medMap as Map<String, dynamic>))
          .toList() ?? [];

      // جدولة كل دواء
      for (final med in medsList) {
        await _scheduleMedication(elderlyId, med);
      }

      debugPrint('✅ Scheduled ${medsList.length} medications for $elderlyId');
    } catch (e) {
      debugPrint('❌ Error scheduling medications: $e');
    }
  }

  /// جدولة دواء واحد مع أوقاته المتعددة
  Future<void> _scheduleMedication(String elderlyId, Medication med) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // تحديد الأيام التي يجب تذكير فيها
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

        // لا تجدول في الماضي
        if (scheduledTime.isBefore(now)) continue;

        // تنبيه 1: الوقت الأصلي
        final notifId1 = _generateNotificationId(elderlyId, med.id, i, 0);
        await _notificationService.scheduleNotification(
          id: notifId1,
          title: '💊 وقت الدواء',
          body: 'حان موعد دواء ${med.name}',
          scheduledTime: scheduledTime,
          payload: 'med:$elderlyId:${med.id}:$i',
        );

        // تنبيه 2: بعد 5 دقائق
        final notifId2 = _generateNotificationId(elderlyId, med.id, i, 1);
        await _notificationService.scheduleNotification(
          id: notifId2,
          title: '⏰ تذكير بالدواء',
          body: 'لم تأخذ دواء ${med.name} بعد!',
          scheduledTime: scheduledTime.add(const Duration(minutes: 5)),
          payload: 'reminder:$elderlyId:${med.id}:$i',
        );

        // تنبيه 3: بعد 10 دقائق - سيتم إرساله لـ caregivers
        final notifId3 = _generateNotificationId(elderlyId, med.id, i, 2);
        await _scheduleCaregiversNotification(
          elderlyId: elderlyId,
          medication: med,
          scheduledTime: scheduledTime.add(const Duration(minutes: 10)),
          notificationId: notifId3,
        );
      }
    }
  }

  /// جدولة تنبيه لجميع caregivers المرتبطين بكبير السن
  Future<void> _scheduleCaregiversNotification({
    required String elderlyId,
    required Medication medication,
    required DateTime scheduledTime,
    required int notificationId,
  }) async {
    try {
      // جلب معلومات كبير السن للحصول على اسمه
      final elderlyDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(elderlyId)
          .get();

      final elderlyData = elderlyDoc.data();
      final elderlyName = [
        elderlyData?['firstName'] ?? '',
        elderlyData?['lastName'] ?? '',
      ].where((s) => s.toString().isNotEmpty).join(' ');

      // البحث عن جميع caregivers اللي عندهم هذا الـ elderly
      final caregiversSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'caregiver')
          .where('elderlyIds', arrayContains: elderlyId)
          .get();

      debugPrint(
        '👥 Found ${caregiversSnapshot.docs.length} caregivers for $elderlyId',
      );

      // جدولة تنبيه لكل caregiver
      for (final caregiverDoc in caregiversSnapshot.docs) {
        await _notificationService.scheduleNotification(
          id: notificationId,
          title: '🚨 تنبيه مهم',
          body: '$elderlyName لم يأخذ دواء ${medication.name}!',
          scheduledTime: scheduledTime,
          payload: 'caregiver_alert:$elderlyId:${medication.id}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error scheduling caregiver notification: $e');
    }
  }

  /// توليد ID فريد للتنبيه
  /// elderlyId + medicationId + timeIndex + notificationType (0=main, 1=5min, 2=10min)
  int _generateNotificationId(
    String elderlyId,
    String medicationId,
    int timeIndex,
    int type,
  ) {
    // استخدم hash للحصول على رقم صغير
    final combined = '$elderlyId-$medicationId-$timeIndex-$type';
    return combined.hashCode.abs() % 2147483647; // max int32
  }

  /// تحديد الأيام القادمة للجدولة (7 أيام قادمة)
  List<DateTime> _getDaysToSchedule(List<String> selectedDays, DateTime start) {
    if (selectedDays.contains('Every day')) {
      return List.generate(7, (i) => start.add(Duration(days: i)));
    }

    final daysMap = {
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

    final result = <DateTime>[];
    for (int i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      if (targetWeekdays.contains(day.weekday)) {
        result.add(day);
      }
    }
    return result;
  }

  /// إلغاء جميع التنبيهات لمستخدم معين
  Future<void> cancelAllMedicationsForUser(String elderlyId) async {
    // للأسف flutter_local_notifications ما يعطيك filter حسب payload
    // لذا نلغي الكل ونعيد الجدولة
    await _notificationService.cancelAllNotifications();
    debugPrint('🗑️ Cancelled all notifications');
  }

  /// تحديث جدولة دواء معين بعد التعديل
  Future<void> updateMedicationSchedule(
    String elderlyId,
    Medication medication,
  ) async {
    // أعد جدولة جميع الأدوية (الطريقة الأبسط)
    await scheduleAllMedications(elderlyId);
  }

  /// حذف جدولة دواء معين
  Future<void> deleteMedicationSchedule(
    String elderlyId,
    String medicationId,
  ) async {
    // أعد جدولة جميع الأدوية
    await scheduleAllMedications(elderlyId);
  }

  /// تسجيل أخذ الدواء (إلغاء التنبيهات التالية لهذا الوقت)
  Future<void> markMedicationTaken(
    String elderlyId,
    String medicationId,
    int timeIndex,
  ) async {
    // إلغاء التنبيه الثاني (5 دقائق) والثالث (10 دقائق)
    final notifId2 = _generateNotificationId(elderlyId, medicationId, timeIndex, 1);
    final notifId3 = _generateNotificationId(elderlyId, medicationId, timeIndex, 2);
    
    await _notificationService.cancelNotification(notifId2);
    await _notificationService.cancelNotification(notifId3);
    
    debugPrint('✅ Marked medication as taken, cancelled follow-up notifications');
  }
}
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// تهيئة خدمة التنبيهات
  Future<void> initialize() async {
    if (_initialized) return;

    // تهيئة المناطق الزمنية
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh')); // توقيت الرياض

    // إعدادات Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // إعدادات iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // طلب الأذونات
    await _requestPermissions();

    // إنشاء notification channels
    await _createMedicationNotificationChannel();
    await _createEmergencyNotificationChannel();

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  /// إنشاء notification channel للأدوية
  Future<void> _createMedicationNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'medication_channel',
      'Medication Reminders',
      description: 'Notifications for medication reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Medication notification channel created');
  }

  /// إنشاء notification channel للطوارئ
  Future<void> _createEmergencyNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_channel',
      'Emergency Alerts',
      description: 'Urgent notifications for elderly emergency alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Emergency notification channel created');
  }

  /// طلب أذونات التنبيهات
  Future<void> _requestPermissions() async {
    // طلب إذن التنبيهات العادي
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      debugPrint('📱 Notification permission: $status');
    }

    // طلب إذن Exact Alarm للتنبيهات المجدولة
    if (await Permission.scheduleExactAlarm.isDenied) {
      final status = await Permission.scheduleExactAlarm.request();
      debugPrint('⏰ Exact alarm permission: $status');
    }

    final notifStatus = await Permission.notification.status;
    final alarmStatus = await Permission.scheduleExactAlarm.status;

    if (notifStatus.isGranted && alarmStatus.isGranted) {
      debugPrint('✅ All permissions granted');
    } else {
      debugPrint('⚠️ Missing permissions:');
      debugPrint('   Notification: $notifStatus');
      debugPrint('   Exact Alarm: $alarmStatus');
    }
  }

  /// معالجة الضغط على التنبيه
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // يمكنك إضافة navigation هنا لاحقاً
  }

  /// جدولة تنبيه في وقت محدد
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          'Medication Reminders',
          channelDescription: 'Notifications for medication reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('📅 Scheduled notification #$id for ${scheduledTime.toString()}');
  }

  /// عرض تنبيه فوري عام
  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_channel',
          'Medication Reminders',
          channelDescription: 'Notifications for medication reminders',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );

    debugPrint('🔔 Showed immediate notification #$id');
  }

  /// عرض تنبيه فوري للطوارئ
  Future<void> showEmergencyNotification({
    required int id,
    required String elderlyName,
    required String elderlyId,
  }) async {
    await _notifications.show(
      id,
      'Emergency Alert',
      '$elderlyName needs help. Tap to view location.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'emergency_channel',
          'Emergency Alerts',
          channelDescription: 'Urgent notifications for elderly emergency alerts',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          ticker: 'Emergency Alert',
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'emergency_$elderlyId',
    );

    debugPrint('🚨 Showed emergency notification #$id');
  }

  /// إلغاء تنبيه معين
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('❌ Cancelled notification #$id');
  }

  /// إلغاء جميع التنبيهات
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('❌ Cancelled all notifications');
  }

  /// الحصول على جميع التنبيهات المجدولة
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
}

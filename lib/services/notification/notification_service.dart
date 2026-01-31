/// 本地推送通知服务
/// 使用 flutter_local_notifications 实现本地推送

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// 初始化通知服务
  Future<bool> initialize() async {
    if (_initialized) return true;

    // 初始化时区
    tz_data.initializeTimeZones();
    // 设置本地时区
    final String localTimeZone = await _getLocalTimeZone();
    tz.setLocalLocation(tz.getLocation(localTimeZone));

    // Android 初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 初始化设置
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
    return _initialized;
  }

  /// 获取本地时区
  Future<String> _getLocalTimeZone() async {
    // 简单返回东八区（中国标准时间）
    return 'Asia/Shanghai';
  }

  /// 请求通知权限
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Android 13+ 需要请求运行时权限
      final status = await Permission.notification.request();
      return status.isGranted;
    } else if (Platform.isIOS) {
      final bool? result = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }
    return true;
  }

  /// 检查权限状态
  Future<bool> arePermissionsGranted() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    } else if (Platform.isIOS) {
      final permissions = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return permissions?.isEnabled ?? false;
    }
    return true;
  }

  /// 安排单次通知
  Future<int?> scheduleNotification({
    required int id,
    required String title,
    String? body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final notificationDetails = _getNotificationDetails();

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      return id;
    } catch (e) {
      debugPrint('安排通知失败: $e');
      return null;
    }
  }

  /// 安排每日重复通知
  Future<int?> scheduleDailyNotification({
    required int id,
    required String title,
    String? body,
    required TimeOfDay time,
    String? payload,
  }) async {
    final notificationDetails = _getNotificationDetails();

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfTime(time),
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: payload,
      );
      return id;
    } catch (e) {
      debugPrint('安排每日通知失败: $e');
      return null;
    }
  }

  /// 安排每周重复通知
  Future<int?> scheduleWeeklyNotification({
    required int id,
    required String title,
    String? body,
    required TimeOfDay time,
    required List<int> weekdays, // 1=周一, 7=周日
    String? payload,
  }) async {
    final notificationDetails = _getNotificationDetails();

    try {
      // 为每个工作日创建单独的通知
      for (int i = 0; i < weekdays.length; i++) {
        final weekday = weekdays[i];
        final notificationId = id * 10 + i; // 确保ID唯一

        await _plugin.zonedSchedule(
          notificationId,
          title,
          body,
          _nextInstanceOfWeekday(time, weekday),
          notificationDetails,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
        );
      }
      return id;
    } catch (e) {
      debugPrint('安排每周通知失败: $e');
      return null;
    }
  }

  /// 取消通知
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  /// 获取待发送的通知列表
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }

  /// 获取活跃通知（仅Android）
  Future<List<ActiveNotification>> getActiveNotifications() async {
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.getActiveNotifications() ??
          [];
    }
    return [];
  }

  /// 显示即时通知
  Future<void> showNotification({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    final notificationDetails = _getNotificationDetails();

    await _plugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// 获取通知详情配置
  NotificationDetails _getNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'thick_notepad_channel',
      '动计笔记',
      channelDescription: '动计笔记应用通知',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );
  }

  /// 计算下一个指定时间的实例（每日）
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// 计算下一个指定星期几和时间的实例（每周）
  tz.TZDateTime _nextInstanceOfWeekday(TimeOfDay time, int weekday) {
    var scheduledDate = _nextInstanceOfTime(time);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// 通知点击回调
  void _onNotificationTap(NotificationResponse response) {
    // TODO: 处理通知点击，跳转到对应页面
    debugPrint('通知被点击: ${response.payload}');
  }

  /// 创建通知ID（使用时间戳）
  static int generateId() {
    return DateTime.now().millisecondsSinceEpoch % 1000000000;
  }
}

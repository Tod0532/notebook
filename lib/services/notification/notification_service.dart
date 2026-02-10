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

  /// 通知点击回调
  void Function(String? payload)? onNotificationTap;

  /// 初始化通知服务
  Future<bool> initialize() async {
    if (_initialized) return true;

    debugPrint('NotificationService: 开始初始化...');

    // 初始化时区
    tz_data.initializeTimeZones();
    // 设置本地时区
    final String localTimeZone = await _getLocalTimeZone();
    tz.setLocalLocation(tz.getLocation(localTimeZone));
    debugPrint('NotificationService: 时区设置为 $localTimeZone');

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

    final initialized = await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (initialized != null) {
      // Android 8.0+ 需要创建通知渠道
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      _initialized = true;
      debugPrint('NotificationService: 初始化成功');
    } else {
      debugPrint('NotificationService: 初始化失败');
    }

    return _initialized;
  }

  /// 创建 Android 通知渠道（Android 8.0+ 需要）
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      debugPrint('NotificationService: 无法获取 Android 插件实例');
      return;
    }

    try {
      // 创建最高重要性通知渠道 - 确保在任何时候都显示
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'thick_notepad_channel',
          '慧记',
          description: '慧记应用通知',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          showBadge: true,
          // 修复：移除LED配置，避免兼容性问题
          // enableLights: true,
          // ledColor: Color(0xFF4CAF50),
        ),
      );
      debugPrint('NotificationService: 通知渠道创建成功');
    } catch (e) {
      debugPrint('NotificationService: 创建通知渠道失败: $e');
    }
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
  ///
  /// 修复说明：
  /// - 修复时区转换问题，直接使用本地时间构造 TZDateTime
  /// - 添加了详细的调试日志
  /// - 添加了时间有效性检查
  Future<int?> scheduleNotification({
    required int id,
    required String title,
    String? body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    final notificationDetails = _getNotificationDetails();

    try {
      debugPrint('========== 安排单次通知 ==========');
      debugPrint('通知ID: $id');
      debugPrint('标题: $title');
      debugPrint('提醒时间: $scheduledTime');

      // 检查时间是否在过去
      final now = DateTime.now();
      debugPrint('当前时间: $now');
      final timeDiff = scheduledTime.difference(now);
      debugPrint('时间差: ${timeDiff.inSeconds} 秒 (${timeDiff.inMinutes} 分钟)');

      if (scheduledTime.isBefore(now)) {
        debugPrint('警告: 安排的时间在过去，通知不会触发');
        // 如果时间在过去，不安排通知
        return null;
      }

      if (Platform.isAndroid) {
        // Android: 使用平台特定的方法，避免时区问题
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          // 直接构造本地时区的 TZDateTime（避免 from() 的转换问题）
          final tzTime = tz.TZDateTime(
            tz.local,
            scheduledTime.year,
            scheduledTime.month,
            scheduledTime.day,
            scheduledTime.hour,
            scheduledTime.minute,
            scheduledTime.second,
          );
          debugPrint('转换后时区时间: $tzTime');
          debugPrint('当前时区时间: ${tz.TZDateTime.now(tz.local)}');

          // 获取 Android 平台特定的通知详情
          final androidDetails = notificationDetails.android;

          // 使用 exactAllowWhileIdle 模式
          await androidPlugin.zonedSchedule(
            id,
            title,
            body,
            tzTime,
            androidDetails,
            scheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
          debugPrint('通知安排成功(Android): id=$id');

          // 验证通知是否真的被安排
          final pending = await getPendingNotifications();
          debugPrint('当前待发送通知数量: ${pending.length}');
          for (final p in pending) {
            debugPrint('  - id=${p.id}, title=${p.title}, body=${p.body}');
          }

          debugPrint('====================================');
          return id;
        }
      }

      // iOS 或降级方案: 使用时区感知的方法
      final tzTime = tz.TZDateTime(
        tz.local,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
        scheduledTime.second,
      );
      debugPrint('使用时区方法(iOS/降级): $tzTime');

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );

      debugPrint('通知安排成功: id=$id');
      debugPrint('====================================');
      return id;
    } catch (e, stackTrace) {
      debugPrint('安排通知失败: $e');
      debugPrint('堆栈: $stackTrace');
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

  /// 显示即时通知（用于测试通知权限和系统设置）
  Future<void> showNotification({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    final notificationDetails = _getNotificationDetails();

    debugPrint('显示即时通知: id=$id, title=$title');

    try {
      await _plugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      debugPrint('即时通知显示成功');
    } catch (e) {
      debugPrint('显示即时通知失败: $e');
    }
  }

  /// 测试通知系统 - 先显示即时通知，再显示5秒后的通知
  Future<void> testNotificationSystem() async {
    debugPrint('========== 通知系统测试开始 ==========');

    // 1. 检查初始化状态
    debugPrint('初始化状态: $_initialized');
    if (!_initialized) {
      await initialize();
    }

    // 2. 检查权限
    final hasPermission = await arePermissionsGranted();
    debugPrint('通知权限: $hasPermission');

    // 3. 获取待发送通知（测试前）
    final pendingBefore = await getPendingNotifications();
    debugPrint('测试前待发送通知数量: ${pendingBefore.length}');

    // 4. 先显示即时通知（验证通知系统是否工作）
    debugPrint('显示即时测试通知...');
    try {
      await _plugin.show(
        888888,
        '即时测试通知',
        '如果您看到这条通知，说明通知系统工作正常！',
        _getNotificationDetails(),
        payload: 'test_immediate',
      );
      debugPrint('即时通知显示成功');
    } catch (e) {
      debugPrint('即时通知显示失败: $e');
    }

    // 5. 安排5秒后的通知
    final testTime = DateTime.now().add(const Duration(seconds: 5));
    debugPrint('安排5秒后的测试通知: $testTime');

    try {
      final tzTime = tz.TZDateTime.from(testTime, tz.local);
      debugPrint('转换后的时区时间: $tzTime');
      debugPrint('当前时区时间: ${tz.TZDateTime.now(tz.local)}');

      await _plugin.zonedSchedule(
        999999,
        '5秒后测试',
        '这是5秒后的测试通知，应该能收到！',
        tzTime,
        _getNotificationDetails(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'test_scheduled',
      );
      debugPrint('5秒后通知安排成功');
    } catch (e) {
      debugPrint('5秒后通知安排失败: $e');
    }

    // 6. 获取待发送通知（测试后）
    final pendingAfter = await getPendingNotifications();
    debugPrint('测试后待发送通知数量: ${pendingAfter.length}');
    for (final p in pendingAfter) {
      debugPrint('  - id=${p.id}, title=${p.title}, body=${p.body}');
    }

    // 7. 获取活跃通知（仅Android）
    if (Platform.isAndroid) {
      try {
        final active = await getActiveNotifications();
        debugPrint('活跃通知数量: ${active.length}');
      } catch (e) {
        debugPrint('获取活跃通知失败: $e');
      }
    }

    debugPrint('========== 通知系统测试结束 ==========');
  }

  /// 获取通知详情配置
  NotificationDetails _getNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'thick_notepad_channel',
      '慧记',
      channelDescription: '慧记应用通知',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(''),
      enableVibration: true,
      playSound: true,
      // 修复：移除LED配置，避免旧版本Android报错
      // enableLights: true,
      // ledColor: Color(0xFF4CAF50),
      // ledOnMs: 100,
      // ledOffMs: 100,
      fullScreenIntent: false,
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
    debugPrint('通知被点击: ${response.payload}');
    // 调用外部设置的回调
    onNotificationTap?.call(response.payload);
  }

  /// 创建通知ID（使用时间戳）
  static int generateId() {
    return DateTime.now().millisecondsSinceEpoch % 1000000000;
  }

  // ==================== 计划迭代提醒 ====================

  /// 检查并发送计划迭代提醒
  ///
  /// [daysSinceUpdate] 距上次更新的天数（7或14天）
  /// [userProfileId] 用户画像ID
  /// [planType] 计划类型 ('workout' 或 'diet')
  /// [planName] 计划名称
  Future<int?> checkAndSendPlanUpdateReminder({
    required int daysSinceUpdate,
    required int? userProfileId,
    required String planType,
    String? planName,
  }) async {
    // 计算通知ID（基于用户画像ID和计划类型，确保唯一）
    final notificationId = 900000 + (userProfileId ?? 0) * 10 + (planType == 'workout' ? 1 : 2);

    final title = planType == 'workout' ? '训练计划更新提醒' : '饮食计划更新提醒';
    final body = planName != null
        ? '您的「$planName」已执行 $daysSinceUpdate 天，建议根据最新数据更新计划'
        : '您的AI计划已执行 $daysSinceUpdate 天，建议根据最新数据更新计划';

    // 设置提醒时间（明天上午9点）
    final now = tz.TZDateTime.now(tz.local);
    var scheduledTime = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 9, 0);

    if (scheduledTime.isBefore(now)) {
      // 如果计算出的时间已过，设置为后天
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final notificationDetails = _getNotificationDetails();

    try {
      await _plugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTime,
        notificationDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'plan_update_$planType',
      );
      return notificationId;
    } catch (e) {
      debugPrint('安排计划更新提醒失败: $e');
      return null;
    }
  }

  /// 取消计划迭代提醒
  Future<void> cancelPlanUpdateReminder({
    required int? userProfileId,
    required String planType,
  }) async {
    final notificationId = 900000 + (userProfileId ?? 0) * 10 + (planType == 'workout' ? 1 : 2);
    await _plugin.cancel(notificationId);
  }

  /// 取消所有计划迭代提醒
  Future<void> cancelAllPlanUpdateReminders() async {
    // 计划提醒的ID范围是 900000-999999
    for (int i = 900000; i < 990000; i++) {
      await _plugin.cancel(i);
    }
  }
}

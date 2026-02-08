/// 应用常量定义

class AppConstants {
  // 应用信息
  static const String appName = '慧记';
  static const String appVersion = '1.0.1';

  // 存储键
  static const String keyThemeMode = 'theme_mode';
  static const String keyFirstLaunch = 'first_launch';
  static const String keyLastBackup = 'last_backup';

  // 通知ID
  static const int notificationIdReminder = 1000;
  static const int notificationIdWorkout = 2000;
  static const int notificationIdPlan = 3000;

  // 通知渠道
  static const String channelIdReminders = 'reminders';
  static const String channelNameReminders = '提醒通知';

  static const String channelIdWorkouts = 'workouts';
  static const String channelNameWorkouts = '运动提醒';

  static const String channelIdPlans = 'plans';
  static const String channelNamePlans = '计划提醒';

  // 分页
  static const int pageSize = 20;

  // 动画时长
  static const int animationDurationShort = 150;
  static const int animationDurationMedium = 300;
  static const int animationDurationLong = 500;

  // 文本限制
  static const int maxNoteTitleLength = 100;
  static const int maxNoteContentLength = 10000;
  static const int maxReminderTitleLength = 100;
  static const int maxTagsPerNote = 10;
  static const int maxTagNameLength = 20;

  // 日期格式
  static const String dateFormatDisplay = 'yyyy年MM月dd日';
  static const String dateFormatShort = 'MM/dd';
  static const String dateFormatMonthDay = 'M月d日';
  static const String dateFormatWeekday = 'EEEE';
  static const String timeFormatDisplay = 'HH:mm';
  static const String dateTimeFormatDisplay = 'yyyy年MM月dd日 HH:mm';
}

/// 日期格式化工具
class DateFormats {
  static const String display = 'yyyy年MM月dd日';
  static const String short = 'MM/dd';
  static const String monthDay = 'M月d日';
  static const String time = 'HH:mm';
  static const String dateTime = 'yyyy年MM月dd日 HH:mm';
}

// 动计笔记 - 数据库定义
// 使用 Drift (SQLite) 进行本地数据存储

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ==================== 数据表定义 ====================

/// 笔记表
@DataClassName('Note')
class Notes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  TextColumn get tags => text().withDefault(const Constant('[]'))(); // JSON数组
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  IntColumn get color => integer().nullable()(); // 颜色标记

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {createdAt}, // 按创建时间查询
    {isDeleted}, // 过滤已删除笔记
    {isPinned}, // 查询置顶笔记
  ];
}

/// 提醒表
@DataClassName('Reminder')
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get remindTime => dateTime()();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get repeatType => text().withDefault(const Constant('none'))(); // none/daily/weekly
  TextColumn get repeatDays => text().nullable()(); // JSON数组 [1,3,5] 星期几
  DateTimeColumn get repeatEndDate => dateTime().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get linkedPlanId => integer().nullable()(); // 关联的计划ID
  IntColumn get linkedWorkoutId => integer().nullable()(); // 关联的运动ID

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {remindTime}, // 按提醒时间查询
    {isDone}, // 过滤已完成提醒
    {isEnabled}, // 过滤启用提醒
    {linkedPlanId}, // 关联计划查询
    {linkedWorkoutId}, // 关联运动查询
  ];
}

/// 运动记录表
@DataClassName('Workout')
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // 运动类型
  TextColumn get customTypeName => text().nullable()(); // 自定义类型名
  DateTimeColumn get startTime => dateTime()();
  IntColumn get durationMinutes => integer()();
  TextColumn get notes => text().nullable()();
  IntColumn get sets => integer().nullable()(); // 组数
  IntColumn get reps => integer().nullable()(); // 次数
  RealColumn get weight => real().nullable()(); // 重量(kg)
  TextColumn get feeling => text().nullable()(); // easy/medium/hard
  RealColumn get distance => real().nullable()(); // 距离 - 后期GPS功能
  RealColumn get calories => real().nullable()(); // 卡路里
  IntColumn get linkedPlanId => integer().nullable()(); // 完成的计划ID
  IntColumn get linkedNoteId => integer().nullable()(); // 生成的笔记ID

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {startTime}, // 按开始时间查询（本周/本月运动）
    {type}, // 按运动类型查询
    {linkedPlanId}, // 关联计划查询
    {linkedNoteId}, // 关联笔记查询
  ];
}

/// 计划表
@DataClassName('Plan')
class Plans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text()(); // workout/habit/study/work/other
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get targetDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active/completed/paused
  IntColumn get totalTasks => integer().withDefault(const Constant(0))();
  IntColumn get completedTasks => integer().withDefault(const Constant(0))();
  IntColumn get streakDays => integer().withDefault(const Constant(0))(); // 连续天数
  BoolColumn get isAIGenerated => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {status}, // 按状态查询（进行中的计划）
    {category}, // 按分类查询
    {targetDate}, // 按目标日期查询
    {createdAt}, // 按创建时间查询
  ];
}

/// 计划任务表
@DataClassName('PlanTask')
class PlanTasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer().references(Plans, #id)();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get scheduledDate => dateTime()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get taskType => text()(); // workout/note/reminder/general
  IntColumn get linkedItemId => integer().nullable()(); // 关联项目ID
  IntColumn get reminderId => integer().nullable()(); // 关联的提醒ID

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {planId}, // 按计划ID查询任务列表
    {scheduledDate}, // 按日期查询（今日/本周任务）
    {isCompleted}, // 过滤已完成/未完成任务
    {taskType}, // 按任务类型查询
  ];
}

// ==================== 数据库类 ====================

/// 应用数据库
@DriftDatabase(tables: [Notes, Reminders, Workouts, Plans, PlanTasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // 未来版本升级时使用
      },
    );
  }
}

// ==================== 数据库单例 ====================

/// 数据库提供者 - 线程安全单例
/// 使用 Dart 推荐的异步单例模式
class DatabaseProvider {
  static AppDatabase? _instance;
  static final _lock = Object();

  /// 获取数据库实例（线程安全）
  static AppDatabase get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= _createDatabase();
      });
    }
    return _instance!;
  }

  /// 同步锁操作
  static void synchronized(Object lock, void Function() fn) {
    // Dart 是单线程模型，这里的锁主要用于代码层面的保护
    // 在真正的多线程环境需要使用 Isolate
    if (_instance == null) {
      fn();
    }
  }

  static AppDatabase _createDatabase() {
    final executor = LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'thick_notepad.db'));
      return NativeDatabase.createInBackground(file);
    });
    return AppDatabase(executor);
  }

  /// 关闭数据库连接
  static Future<void> close() async {
    final instance = _instance;
    if (instance != null) {
      await instance.close();
      _instance = null;
    }
  }
}

// ==================== 运动类型枚举 ====================

enum WorkoutType {
  // 有氧类
  running('跑步', 'cardio'),
  cycling('骑行', 'cardio'),
  swimming('游泳', 'cardio'),
  jumpRope('跳绳', 'cardio'),
  hiit('HIIT', 'cardio'),
  aerobics('有操', 'cardio'),
  stairClimbing('爬楼梯', 'cardio'),

  // 力量类
  chest('胸肌', 'strength'),
  back('背肌', 'strength'),
  legs('腿部', 'strength'),
  shoulders('肩部', 'strength'),
  arms('手臂', 'strength'),
  core('核心', 'strength'),
  fullBody('全身', 'strength'),

  // 球类
  basketball('篮球', 'sports'),
  football('足球', 'sports'),
  badminton('羽毛球', 'sports'),
  tableTennis('乒乓球', 'sports'),
  tennis('网球', 'sports'),
  volleyball('排球', 'sports'),

  // 其他
  yoga('瑜伽', 'other'),
  pilates('普拉提', 'other'),
  hiking('徒步', 'other'),
  climbing('登山', 'other'),
  meditation('冥想', 'other'),
  stretching('拉伸', 'other'),
  walking('散步', 'other'),
  other('其他', 'other');

  final String displayName;
  final String category;

  const WorkoutType(this.displayName, this.category);

  static WorkoutType? fromString(String value) {
    return WorkoutType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => WorkoutType.other,
    );
  }

  static List<WorkoutType> getByCategory(String category) {
    return WorkoutType.values.where((e) => e.category == category).toList();
  }
}

// ==================== 计划分类枚举 ====================

enum PlanCategory {
  workout('运动', 'fitness'),
  habit('习惯', 'lifestyle'),
  study('学习', 'growth'),
  work('工作', 'career'),
  health('健康', 'wellness'),
  other('其他', 'general');

  final String displayName;
  final String icon;

  const PlanCategory(this.displayName, this.icon);

  static PlanCategory? fromString(String value) {
    try {
      return PlanCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

// ==================== 重复类型枚举 ====================

enum RepeatType {
  none('单次'),
  daily('每天'),
  weekly('每周'),
  monthly('每月'),
  custom('自定义');

  final String displayName;

  const RepeatType(this.displayName);

  static RepeatType fromString(String value) {
    return RepeatType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RepeatType.none,
    );
  }
}

// ==================== 任务类型枚举 ====================

enum TaskType {
  workout('运动', 'fitness'),
  note('笔记', 'note'),
  reminder('提醒', 'reminder'),
  general('普通', 'general');

  final String displayName;
  final String icon;

  const TaskType(this.displayName, this.icon);

  static TaskType fromString(String value) {
    return TaskType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaskType.general,
    );
  }
}

// ==================== 计划状态枚举 ====================

enum PlanStatus {
  active('进行中'),
  completed('已完成'),
  paused('已暂停'),
  cancelled('已取消');

  final String displayName;

  const PlanStatus(this.displayName);

  static PlanStatus fromString(String value) {
    return PlanStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PlanStatus.active,
    );
  }
}

// ==================== 运动感受枚举 ====================

enum FeelingLevel {
  easy('轻松', 1),
  medium('适中', 2),
  hard('疲惫', 3);

  final String displayName;
  final int level;

  const FeelingLevel(this.displayName, this.level);

  static FeelingLevel fromString(String value) {
    return FeelingLevel.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FeelingLevel.medium,
    );
  }
}

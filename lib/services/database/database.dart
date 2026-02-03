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
  TextColumn get folder => text().nullable()(); // 文件夹分类
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
    {folder}, // 按文件夹查询
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

// ==================== AI教练功能数据表 ====================

/// 用户画像表 - 存储用户的基础信息、目标、限制条件等
@DataClassName('UserProfile')
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  // 目标相关
  TextColumn get goalType => text()(); // fat_loss/muscle_gain/shape/maintain/fitness
  IntColumn get goalDurationDays => integer().nullable()(); // 目标周期（天）
  RealColumn get targetWeight => real().nullable()(); // 目标体重
  RealColumn get targetBodyFat => real().nullable()(); // 目标体脂率

  // 基础信息
  TextColumn get gender => text()(); // male/female
  IntColumn get age => integer()();
  RealColumn get height => real()(); // 身高
  RealColumn get weight => real()(); // 当前体重
  RealColumn get bodyFat => real().nullable()(); // 体脂率
  TextColumn get fitnessLevel => text()(); // beginner/novice/intermediate/advanced

  // 限制条件
  TextColumn get dietaryRestrictions => text().nullable()(); // JSON数组：饮食禁忌
  TextColumn get allergies => text().nullable()(); // JSON数组：过敏食材
  TextColumn get dietType => text().withDefault(const Constant('none'))(); // none/vegetarian/vegan
  TextColumn get injuries => text().nullable()(); // JSON数组：运动损伤
  TextColumn get availableTimeSlots => text().nullable()(); // JSON数组：可运动时间段
  IntColumn get dailyWorkoutMinutes => integer().nullable()(); // 每日可运动时长

  // 偏好
  TextColumn get tastePreference => text().nullable()(); // spicy/light/sweet/savory
  TextColumn get preferredWorkouts => text().nullable()(); // JSON数组：喜欢的运动
  TextColumn get dislikedWorkouts => text().nullable()(); // JSON数组：讨厌的运动
  TextColumn get equipmentType => text()(); // none/home_minimal/gym_full

  // 心率设备
  BoolColumn get hasHeartRateMonitor => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {createdAt}, // 按创建时间查询
  ];
}

/// AI训练计划表
@DataClassName('WorkoutPlan')
class WorkoutPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userProfileId => integer().references(UserProfiles, #id)();

  TextColumn get name => text()(); // 计划名称
  TextColumn get description => text().nullable()(); // 计划描述
  TextColumn get goalType => text()(); // 目标类型
  IntColumn get totalDays => integer()(); // 总天数
  IntColumn get currentDay => integer().withDefault(const Constant(1))(); // 当前第几天

  TextColumn get status => text().withDefault(const Constant('active'))(); // active/completed/paused

  DateTimeColumn get startDate => dateTime().nullable()(); // 开始日期
  DateTimeColumn get targetEndDate => dateTime().nullable()(); // 目标结束日期
  DateTimeColumn get actualEndDate => dateTime().nullable()(); // 实际结束日期

  IntColumn get totalWorkouts => integer().withDefault(const Constant(0))(); // 总训练次数
  IntColumn get completedWorkouts => integer().withDefault(const Constant(0))(); // 已完成训练次数

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {userProfileId}, // 按用户画像查询
    {status}, // 按状态查询
    {startDate}, // 按开始日期查询
  ];
}

/// 训练计划日程表 - 每日的训练安排
@DataClassName('WorkoutPlanDay')
class WorkoutPlanDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutPlanId => integer().references(WorkoutPlans, #id)();
  IntColumn get dayNumber => integer()(); // 第几天

  TextColumn get dayName => text().nullable()(); // 如"第1天 - 胸肩训练"
  TextColumn get trainingFocus => text().nullable()(); // 训练重点：chest_shoulders/legs/等

  IntColumn get estimatedMinutes => integer().nullable()(); // 预计时长

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get scheduledDate => dateTime().nullable()(); // 计划日期

  TextColumn get notes => text().nullable()(); // 备注

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {workoutPlanId}, // 按训练计划查询
    {dayNumber}, // 按天数查询
    {scheduledDate}, // 按计划日期查询
    {isCompleted}, // 过滤已完成/未完成
  ];
}

/// 训练动作表 - 每日训练的具体动作
@DataClassName('WorkoutPlanExercise')
class WorkoutPlanExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutPlanDayId => integer().references(WorkoutPlanDays, #id)();

  IntColumn get exerciseOrder => integer()(); // 动作顺序

  TextColumn get exerciseName => text()(); // 动作名称
  TextColumn get description => text().nullable()(); // 动作描述/做法

  IntColumn get sets => integer().nullable()(); // 组数
  IntColumn get reps => integer().nullable()(); // 次数
  TextColumn get repsDescription => text().nullable()(); // 次数描述（如"12-15次"）
  RealColumn get weight => real().nullable()(); // 重量
  IntColumn get restSeconds => integer().nullable()(); // 组间休息秒数

  TextColumn get equipment => text().nullable()(); // 所需器械
  TextColumn get difficulty => text().nullable()(); // 难度：easy/medium/hard

  TextColumn get exerciseType => text()(); // warm_up/main/stretch

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  TextColumn get alternativeExercise => text().nullable()(); // 替换动作

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {workoutPlanDayId}, // 按训练日程查询
    {exerciseOrder}, // 按顺序查询
  ];
}

/// 饮食计划表
@DataClassName('DietPlan')
class DietPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userProfileId => integer().references(UserProfiles, #id)();

  TextColumn get name => text()(); // 计划名称
  TextColumn get description => text().nullable()(); // 计划描述
  TextColumn get goalType => text()(); // 目标类型

  IntColumn get totalDays => integer()(); // 总天数
  IntColumn get currentDay => integer().withDefault(const Constant(1))(); // 当前第几天

  // 营养目标
  RealColumn get dailyCalories => real().nullable()(); // 每日目标热量
  RealColumn get dailyProtein => real().nullable()(); // 每日目标蛋白质
  RealColumn get dailyCarbs => real().nullable()(); // 每日目标碳水
  RealColumn get dailyFat => real().nullable()(); // 每日目标脂肪

  TextColumn get status => text().withDefault(const Constant('active'))(); // active/completed/paused

  DateTimeColumn get startDate => dateTime().nullable()();
  DateTimeColumn get targetEndDate => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {userProfileId}, // 按用户画像查询
    {status}, // 按状态查询
    {startDate}, // 按开始日期查询
  ];
}

/// 饮食计划餐次表 - 每日的餐次安排
@DataClassName('DietPlanMeal')
class DietPlanMeals extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dietPlanId => integer().references(DietPlans, #id)();
  IntColumn get dayNumber => integer()(); // 第几天

  TextColumn get mealType => text()(); // breakfast/lunch/dinner/snack
  TextColumn get mealName => text().nullable()(); // 餐次名称

  RealColumn get calories => real().nullable()(); // 热量
  RealColumn get protein => real().nullable()(); // 蛋白质
  RealColumn get carbs => real().nullable()(); // 碳水
  RealColumn get fat => real().nullable()(); // 脂肪

  TextColumn get eatingTime => text().nullable()(); // 建议进食时间

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get scheduledDate => dateTime().nullable()(); // 计划日期

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {dietPlanId}, // 按饮食计划查询
    {dayNumber}, // 按天数查询
    {mealType}, // 按餐次类型查询
    {scheduledDate}, // 按计划日期查询
  ];
}

/// 食材项表 - 每餐的具体食材
@DataClassName('MealItem')
class MealItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get dietPlanMealId => integer().references(DietPlanMeals, #id)();

  TextColumn get foodName => text()(); // 食材名称
  TextColumn get amount => text().nullable()(); // 用量（如"100g"、"1个"）
  RealColumn get weightGrams => real().nullable()(); // 重量（克）

  RealColumn get calories => real().nullable()(); // 热量
  RealColumn get protein => real().nullable()(); // 蛋白质
  RealColumn get carbs => real().nullable()(); // 碳水
  RealColumn get fat => real().nullable()(); // 脂肪

  TextColumn get cookingMethod => text().nullable()(); // 做法描述

  TextColumn get alternatives => text().nullable()(); // 替换食材（JSON数组）

  IntColumn get itemOrder => integer().nullable()(); // 顺序

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {dietPlanMealId}, // 按餐次查询
    {itemOrder}, // 按顺序查询
  ];
}

/// 用户反馈表 - 记录用户对动作/食材的反馈，用于AI优化
@DataClassName('UserFeedback')
class UserFeedbacks extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get feedbackType => text()(); // exercise/food
  IntColumn get itemId => integer()(); // 关联项ID（动作ID或食材ID）
  TextColumn get itemType => text()(); // 具体类型（用于识别）

  TextColumn get reason => text()(); // 反馈原因
  // 动作原因: too_hard/too_easy/dislike/no_equipment
  // 食材原因: unavailable/too_hard/dislike/allergy

  TextColumn get originalName => text()(); // 原始名称
  TextColumn get replacementName => text().nullable()(); // 替换后名称

  IntColumn get userProfileId => integer().references(UserProfiles, #id).nullable()();

  TextColumn get notes => text().nullable()(); // 用户备注

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {userProfileId}, // 按用户查询
    {feedbackType}, // 按反馈类型查询
    {reason}, // 按原因统计
    {createdAt}, // 按时间查询
  ];
}

// ==================== 心率监测功能数据表 ====================

/// 心率记录表 - 存储实时心率数据
@DataClassName('HeartRateRecord')
class HeartRateRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  // 心率数据
  IntColumn get heartRate => integer()(); // 心率值 (BPM)
  IntColumn get rrInterval => integer().nullable()(); // RR间隔 (毫秒)，用于计算心率变异性

  // 时间信息
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)(); // 记录时间

  // 会话关联
  TextColumn get sessionId => text()(); // 监测会话ID (UUID格式)
  IntColumn get linkedWorkoutId => integer().references(Workouts, #id).nullable()(); // 关联的运动ID

  // 设备信息
  TextColumn get deviceId => text().nullable()(); // BLE设备ID
  TextColumn get deviceName => text().nullable()(); // BLE设备名称

  // 数据质量
  IntColumn get signalQuality => integer().nullable()(); // 信号质量 (0-100)

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {sessionId}, // 按会话查询
    {timestamp}, // 按时间查询（用于绘制图表）
    {linkedWorkoutId}, // 按关联运动查询
    {deviceId}, // 按设备查询
  ];
}

/// 心率区间配置表 - 存储用户的心率区间设置
@DataClassName('HeartRateZone')
class HeartRateZones extends Table {
  IntColumn get id => integer().autoIncrement()();

  // 用户关联
  IntColumn get userProfileId => integer().references(UserProfiles, #id).nullable()();

  // 基础心率
  IntColumn get restingHeartRate => integer().withDefault(const Constant(70))(); // 静息心率
  IntColumn get maxHeartRate => integer().nullable()(); // 最大心率（如果为空则使用公式计算）

  // 区间配置
  IntColumn get zone1Min => integer().nullable()(); // 热身区间最小值 (50-60%)
  IntColumn get zone1Max => integer().nullable()(); // 热身区间最大值
  TextColumn get zone1Name => text().withDefault(const Constant('热身'))(); // 热身区间名称

  IntColumn get zone2Min => integer().nullable()(); // 燃脂区间最小值 (60-70%)
  IntColumn get zone2Max => integer().nullable()(); // 燃脂区间最大值
  TextColumn get zone2Name => text().withDefault(const Constant('燃脂'))(); // 燃脂区间名称

  IntColumn get zone3Min => integer().nullable()(); // 有氧区间最小值 (70-80%)
  IntColumn get zone3Max => integer().nullable()(); // 有氧区间最大值
  TextColumn get zone3Name => text().withDefault(const Constant('有氧'))(); // 有氧区间名称

  IntColumn get zone4Min => integer().nullable()(); // 无氧区间最小值 (80-90%)
  IntColumn get zone4Max => integer().nullable()(); // 无氧区间最大值
  TextColumn get zone4Name => text().withDefault(const Constant('无氧'))(); // 无氧区间名称

  IntColumn get zone5Min => integer().nullable()(); // 极限区间最小值 (90-100%)
  IntColumn get zone5Max => integer().nullable()(); // 极限区间最大值
  TextColumn get zone5Name => text().withDefault(const Constant('极限'))(); // 极限区间名称

  // 计算方法
  TextColumn get calculationMethod => text().withDefault(const Constant('age_based'))(); // age_based/measured

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {userProfileId}, // 按用户画像查询
    {createdAt}, // 按创建时间查询
  ];
}

/// 心率监测会话表 - 记录每次监测会话的汇总信息
@DataClassName('HeartRateSession')
class HeartRateSessions extends Table {
  IntColumn get id => integer().autoIncrement()();

  // 会话标识
  TextColumn get sessionId => text()(); // 会话ID (UUID格式)

  // 时间信息
  DateTimeColumn get startTime => dateTime()(); // 开始时间
  DateTimeColumn get endTime => dateTime().nullable()(); // 结束时间

  // 会话统计
  IntColumn get averageHeartRate => integer().nullable()(); // 平均心率
  IntColumn get minHeartRate => integer().nullable()(); // 最低心率
  IntColumn get maxHeartRate => integer().nullable()(); // 最高心率

  // 区间统计（各区间停留时长，秒）
  IntColumn get zone1Duration => integer().withDefault(const Constant(0))();
  IntColumn get zone2Duration => integer().withDefault(const Constant(0))();
  IntColumn get zone3Duration => integer().withDefault(const Constant(0))();
  IntColumn get zone4Duration => integer().withDefault(const Constant(0))();
  IntColumn get zone5Duration => integer().withDefault(const Constant(0))();

  // 关联信息
  IntColumn get linkedWorkoutId => integer().references(Workouts, #id).nullable()(); // 关联的运动ID

  // 设备信息
  TextColumn get deviceId => text().nullable()(); // 使用的设备ID
  TextColumn get deviceName => text().nullable()(); // 使用的设备名称

  // 状态
  TextColumn get status => text().withDefault(const Constant('active'))(); // active/completed/cancelled

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// 索引：优化查询性能
  List<Set<Column>> get indexes => [
    {sessionId}, // 按会话ID查询
    {startTime}, // 按开始时间查询
    {linkedWorkoutId}, // 按关联运动查询
    {status}, // 按状态查询
  ];
}

// ==================== 数据库类 ====================

/// 应用数据库
@DriftDatabase(
  tables: [
    Notes,
    Reminders,
    Workouts,
    Plans,
    PlanTasks,
    // AI教练功能表
    UserProfiles,
    WorkoutPlans,
    WorkoutPlanDays,
    WorkoutPlanExercises,
    DietPlans,
    DietPlanMeals,
    MealItems,
    // 用户反馈表
    UserFeedbacks,
    // 心率监测表
    HeartRateRecords,
    HeartRateZones,
    HeartRateSessions,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // 版本1 -> 版本2：添加AI教练功能表
        if (from == 1 && to == 2) {
          // 创建AI教练相关的新表
          await m.createTable(userProfiles);
          await m.createTable(workoutPlans);
          await m.createTable(workoutPlanDays);
          await m.createTable(workoutPlanExercises);
          await m.createTable(dietPlans);
          await m.createTable(dietPlanMeals);
          await m.createTable(mealItems);
        }
        // 版本2 -> 版本3：添加用户反馈表
        if (from == 2 && to == 3) {
          await m.createTable(userFeedbacks);
        }
        // 版本3 -> 版本4：添加笔记文件夹字段
        if (from == 3 && to == 4) {
          await m.addColumn(notes, notes.folder);
        }
        // 版本4 -> 版本5：添加心率监测功能表
        if (from == 4 && to == 5) {
          await m.createTable(heartRateRecords);
          await m.createTable(heartRateZones);
          await m.createTable(heartRateSessions);
        }
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

// ==================== AI教练功能枚举 ====================

/// 健身目标类型
enum FitnessGoal {
  fatLoss('减脂', 'fat_loss'),
  muscleGain('增肌', 'muscle_gain'),
  shape('塑形', 'shape'),
  maintain('维持体重', 'maintain'),
  fitness('提升体能', 'fitness');

  final String displayName;
  final String value;

  const FitnessGoal(this.displayName, this.value);

  static FitnessGoal fromString(String value) {
    return FitnessGoal.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FitnessGoal.maintain,
    );
  }
}

/// 运动基础等级
enum FitnessLevel {
  beginner('零基础', 'beginner'),
  novice('新手', 'novice'),
  intermediate('有一定基础', 'intermediate'),
  advanced('资深', 'advanced');

  final String displayName;
  final String value;

  const FitnessLevel(this.displayName, this.value);

  static FitnessLevel fromString(String value) {
    return FitnessLevel.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FitnessLevel.beginner,
    );
  }
}

/// 饮食类型
enum DietType {
  none('无限制', 'none'),
  vegetarian('素食', 'vegetarian'),
  vegan('纯素食', 'vegan'),
  ovoVegetarian('蛋奶素', 'ovo_vegetarian');

  final String displayName;
  final String value;

  const DietType(this.displayName, this.value);

  static DietType fromString(String value) {
    return DietType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DietType.none,
    );
  }
}

/// 器械类型
enum EquipmentType {
  none('无器械', 'none'),
  homeMinimal('家用小器械', 'home_minimal'),
  homeFull('家庭健身', 'home_full'),
  gymFull('健身房全套', 'gym_full');

  final String displayName;
  final String value;

  const EquipmentType(this.displayName, this.value);

  static EquipmentType fromString(String value) {
    return EquipmentType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EquipmentType.none,
    );
  }
}

/// 口味偏好
enum TastePreference {
  spicy('辣', 'spicy'),
  light('清淡', 'light'),
  sweet('酸甜', 'sweet'),
  savory('咸香', 'savory');

  final String displayName;
  final String value;

  const TastePreference(this.displayName, this.value);

  static TastePreference? fromString(String value) {
    try {
      return TastePreference.values.firstWhere((e) => e.value == value);
    } catch (_) {
      return null;
    }
  }
}

/// 餐次类型
enum MealType {
  breakfast('早餐', 'breakfast'),
  lunch('午餐', 'lunch'),
  dinner('晚餐', 'dinner'),
  snack('加餐', 'snack');

  final String displayName;
  final String value;

  const MealType(this.displayName, this.value);

  static MealType fromString(String value) {
    return MealType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MealType.snack,
    );
  }
}

/// 训练动作类型
enum ExerciseType {
  warmUp('热身', 'warm_up'),
  main('主训练', 'main'),
  stretch('拉伸', 'stretch');

  final String displayName;
  final String value;

  const ExerciseType(this.displayName, this.value);

  static ExerciseType fromString(String value) {
    return ExerciseType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExerciseType.main,
    );
  }
}

// ==================== 心率监测功能枚举 ====================

/// 心率区间枚举
enum HeartRateZoneEnum {
  zone1('zone1', '热身区间', 50, 60),
  zone2('zone2', '燃脂区间', 60, 70),
  zone3('zone3', '有氧区间', 70, 80),
  zone4('zone4', '无氧区间', 80, 90),
  zone5('zone5', '极限区间', 90, 100);

  final String value;
  final String displayName;
  final int minPercent;
  final int maxPercent;

  const HeartRateZoneEnum(this.value, this.displayName, this.minPercent, this.maxPercent);

  /// 根据心率值获取所在区间
  static HeartRateZoneEnum? getZone(int heartRate, int maxHeartRate) {
    final percent = (heartRate / maxHeartRate * 100).round();
    for (final zone in HeartRateZoneEnum.values) {
      if (percent >= zone.minPercent && percent < zone.maxPercent) {
        return zone;
      }
    }
    if (percent >= 90) return HeartRateZoneEnum.zone5;
    return null;
  }

  /// 获取区间颜色
  String get color {
    switch (this) {
      case HeartRateZoneEnum.zone1:
        return '#60A5FA'; // 蓝色
      case HeartRateZoneEnum.zone2:
        return '#34D399'; // 绿色
      case HeartRateZoneEnum.zone3:
        return '#FBBF24'; // 黄色
      case HeartRateZoneEnum.zone4:
        return '#FB923C'; // 橙色
      case HeartRateZoneEnum.zone5:
        return '#EF4444'; // 红色
    }
  }
}

/// 心率会话状态
enum HeartRateSessionStatus {
  active('进行中'),
  completed('已完成'),
  cancelled('已取消');

  final String displayName;

  const HeartRateSessionStatus(this.displayName);

  static HeartRateSessionStatus fromString(String value) {
    return HeartRateSessionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => HeartRateSessionStatus.active,
    );
  }
}

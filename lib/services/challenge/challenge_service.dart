/// 挑战系统服务
/// 管理每日挑战和每周挑战的生成、进度更新和奖励发放

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/gamification/gamification_service.dart';

// ==================== 挑战定义配置 ====================

/// 挑战类型枚举
enum ChallengeType {
  workout('运动', 'workout'),
  note('笔记', 'note'),
  plan('计划', 'plan'),
  streak('连续打卡', 'streak'),
  totalMinutes('总运动时长', 'total_minutes');

  final String displayName;
  final String value;

  const ChallengeType(this.displayName, this.value);

  static ChallengeType fromString(String value) {
    return ChallengeType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ChallengeType.workout,
    );
  }
}

/// 每日挑战定义
class DailyChallengeDefinition {
  final String title;
  final String description;
  final ChallengeType type;
  final int targetCount;
  final int expReward;
  final int pointsReward;

  const DailyChallengeDefinition({
    required this.title,
    required this.description,
    required this.type,
    required this.targetCount,
    required this.expReward,
    required this.pointsReward,
  });

  /// 转换为数据库实体
  DailyChallengesCompanion toDatabaseEntity(DateTime date) {
    return DailyChallengesCompanion.insert(
      title: title,
      description: description,
      type: type.value,
      targetCount: targetCount,
      expReward: expReward,
      pointsReward: pointsReward,
      date: date,
      dateKey: DateFormat('yyyy-MM-dd').format(date),
      isActive: Value(true),
    );
  }
}

/// 每周挑战定义
class WeeklyChallengeDefinition {
  final String title;
  final String description;
  final ChallengeType type;
  final int targetCount;
  final int expReward;
  final int pointsReward;

  const WeeklyChallengeDefinition({
    required this.title,
    required this.description,
    required this.type,
    required this.targetCount,
    required this.expReward,
    required this.pointsReward,
  });

  /// 转换为数据库实体
  WeeklyChallengesCompanion toDatabaseEntity(int weekNumber, int year) {
    return WeeklyChallengesCompanion.insert(
      title: title,
      description: description,
      type: type.value,
      targetCount: targetCount,
      expReward: expReward,
      pointsReward: pointsReward,
      weekNumber: weekNumber,
      year: year,
      weekKey: '$year-W$weekNumber',
      isActive: Value(true),
    );
  }
}

/// 挑战定义集合
class ChallengeDefinitions {
  /// 每日挑战池
  static const List<DailyChallengeDefinition> dailyChallengePool = [
    // 运动类挑战
    DailyChallengeDefinition(
      title: '运动达人',
      description: '今日完成3次运动记录',
      type: ChallengeType.workout,
      targetCount: 3,
      expReward: 20,
      pointsReward: 10,
    ),
    DailyChallengeDefinition(
      title: '健身入门',
      description: '今日完成1次运动记录',
      type: ChallengeType.workout,
      targetCount: 1,
      expReward: 10,
      pointsReward: 5,
    ),
    DailyChallengeDefinition(
      title: '运动时长挑战',
      description: '今日累计运动30分钟',
      type: ChallengeType.totalMinutes,
      targetCount: 30,
      expReward: 25,
      pointsReward: 15,
    ),

    // 笔记类挑战
    DailyChallengeDefinition(
      title: '笔记高手',
      description: '今日创建2条笔记',
      type: ChallengeType.note,
      targetCount: 2,
      expReward: 10,
      pointsReward: 5,
    ),
    DailyChallengeDefinition(
      title: '记录生活',
      description: '今日创建1条笔记',
      type: ChallengeType.note,
      targetCount: 1,
      expReward: 5,
      pointsReward: 3,
    ),

    // 计划类挑战
    DailyChallengeDefinition(
      title: '计划执行者',
      description: '今日完成2个计划任务',
      type: ChallengeType.plan,
      targetCount: 2,
      expReward: 15,
      pointsReward: 8,
    ),
    DailyChallengeDefinition(
      title: '任务达人',
      description: '今日完成1个计划任务',
      type: ChallengeType.plan,
      targetCount: 1,
      expReward: 8,
      pointsReward: 4,
    ),
  ];

  /// 每周挑战池
  static const List<WeeklyChallengeDefinition> weeklyChallengePool = [
    WeeklyChallengeDefinition(
      title: '周运动冠军',
      description: '本周累计运动5次',
      type: ChallengeType.workout,
      targetCount: 5,
      expReward: 100,
      pointsReward: 50,
    ),
    WeeklyChallengeDefinition(
      title: '运动健将',
      description: '本周累计运动3次',
      type: ChallengeType.workout,
      targetCount: 3,
      expReward: 60,
      pointsReward: 30,
    ),
    WeeklyChallengeDefinition(
      title: '周时长挑战',
      description: '本周累计运动150分钟',
      type: ChallengeType.totalMinutes,
      targetCount: 150,
      expReward: 120,
      pointsReward: 60,
    ),
    WeeklyChallengeDefinition(
      title: '连续打卡王',
      description: '本周连续7天有活动记录',
      type: ChallengeType.streak,
      targetCount: 7,
      expReward: 150,
      pointsReward: 80,
    ),
    WeeklyChallengeDefinition(
      title: '笔记达人',
      description: '本周创建10条笔记',
      type: ChallengeType.note,
      targetCount: 10,
      expReward: 80,
      pointsReward: 40,
    ),
    WeeklyChallengeDefinition(
      title: '计划执行专家',
      description: '本周完成10个计划任务',
      type: ChallengeType.plan,
      targetCount: 10,
      expReward: 100,
      pointsReward: 50,
    ),
  ];

  /// 随机获取每日挑战（每天3个）
  static List<DailyChallengeDefinition> getRandomDailyChallenges() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final challenges = <DailyChallengeDefinition>[];

    // 确保至少有一个运动类挑战
    final workoutChallenges = dailyChallengePool
        .where((c) => c.type == ChallengeType.workout || c.type == ChallengeType.totalMinutes)
        .toList();
    challenges.add(workoutChallenges[random % workoutChallenges.length]);

    // 随机添加其他类型挑战
    final remaining = dailyChallengePool.where((c) => !challenges.contains(c)).toList();
    for (int i = 0; i < 2 && remaining.isNotEmpty; i++) {
      final index = (random + i * 100) % remaining.length;
      challenges.add(remaining[index]);
      remaining.removeAt(index);
    }

    return challenges;
  }

  /// 随机获取每周挑战（每周2个）
  static List<WeeklyChallengeDefinition> getRandomWeeklyChallenges() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final challenges = <WeeklyChallengeDefinition>[];

    // 随机选择2个不同的挑战
    final pool = List<WeeklyChallengeDefinition>.from(weeklyChallengePool);
    for (int i = 0; i < 2 && pool.isNotEmpty; i++) {
      final index = (random + i * 100) % pool.length;
      challenges.add(pool[index]);
      pool.removeAt(index);
    }

    return challenges;
  }
}

// ==================== 挑战服务 ====================

/// 挑战服务 - 单例模式
class ChallengeService {
  static ChallengeService? _instance;
  static final _lock = Object();

  AppDatabase? _database;
  GamificationService? _gamificationService;
  Timer? _dailyRefreshTimer;
  Timer? _weeklyRefreshTimer;

  /// 获取单例实例
  static ChallengeService get instance {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= ChallengeService._internal();
      });
    }
    return _instance!;
  }

  /// 同步锁操作
  static void synchronized(Object lock, void Function() fn) {
    if (_instance == null) {
      fn();
    }
  }

  ChallengeService._internal();

  /// 设置数据库实例
  void setDatabase(AppDatabase database) {
    _database = database;
  }

  /// 设置游戏化服务实例
  void setGamificationService(GamificationService service) {
    _gamificationService = service;
  }

  /// 确保游戏化服务已初始化
  GamificationService get gamificationService {
    if (_gamificationService == null) {
      throw StateError('ChallengeService: 游戏化服务未初始化，请先调用 setGamificationService()');
    }
    return _gamificationService!;
  }

  /// 确保数据库已初始化
  AppDatabase get database {
    if (_database == null) {
      throw StateError('ChallengeService: 数据库未初始化，请先调用 setDatabase()');
    }
    return _database!;
  }

  // ==================== 每日挑战管理 ====================

  /// 生成今日挑战
  Future<List<DailyChallenge>> generateTodayChallenges() async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);

    // 检查今日是否已有挑战
    final existing = await database.getDailyChallengesByDateKey(todayKey);
    if (existing.isNotEmpty) {
      return existing;
    }

    // 生成新挑战
    final challengeDefinitions = ChallengeDefinitions.getRandomDailyChallenges();
    final challenges = <DailyChallenge>[];

    for (final definition in challengeDefinitions) {
      final id = await database.into(database.dailyChallenges).insert(
            definition.toDatabaseEntity(today),
          );
      final challenge = await database.getDailyChallengeById(id);
      if (challenge != null) {
        challenges.add(challenge);

        // 创建对应的进度记录
        await database.into(database.userChallengeProgresses).insert(
              UserChallengeProgressesCompanion.insert(
                challengeId: id,
                date: today,
                currentCount: Value(0),
                isCompleted: Value(false),
                rewardClaimed: Value(false),
              ),
            );
      }
    }

    return challenges;
  }

  /// 获取今日挑战（含进度）
  Future<List<Map<String, dynamic>>> getTodayChallengesWithProgress() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final challenges = await database.getDailyChallengesByDateRange(startOfDay, endOfDay);
    final result = <Map<String, dynamic>>[];

    for (final challenge in challenges) {
      final progress = await database.getUserChallengeProgressByChallengeAndDate(
            challenge.id,
            startOfDay,
          );

      result.add({
        'challenge': challenge,
        'progress': progress,
        'progressPercent': progress != null
            ? (progress.currentCount / challenge.targetCount * 100).clamp(0.0, 100.0)
            : 0.0,
      });
    }

    return result;
  }

  /// 更新挑战进度
  Future<bool> updateChallengeProgress(
    ChallengeType type,
    int countIncrement, {
    int? minutesIncrement,
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final challenges = await database.getDailyChallengesByDateRange(
          startOfDay,
          startOfDay.add(const Duration(days: 1)),
        );

    bool anyUpdated = false;

    for (final challenge in challenges) {
      if (challenge.type != type.value) continue;

      final progress = await database.getUserChallengeProgressByChallengeAndDate(
            challenge.id,
            startOfDay,
          );

      if (progress == null || progress.isCompleted) continue;

      int newCount = progress.currentCount + countIncrement;
      bool isCompleted = false;

      // 特殊处理：总时长类挑战
      if (type == ChallengeType.totalMinutes && minutesIncrement != null) {
        newCount = progress.currentCount + minutesIncrement;
      }

      if (newCount >= challenge.targetCount) {
        newCount = challenge.targetCount;
        isCompleted = true;
      }

      await database.updateUserChallengeProgress(
        UserChallengeProgressesCompanion(
          id: Value(progress.id),
          currentCount: Value(newCount),
          isCompleted: Value(isCompleted),
          completedAt: isCompleted ? Value(DateTime.now()) : Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      anyUpdated = true;
    }

    return anyUpdated;
  }

  /// 领取挑战奖励
  Future<bool> claimChallengeReward(int challengeId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    final progress = await database.getUserChallengeProgressByChallengeAndDate(
          challengeId,
          startOfDay,
        );

    if (progress == null || !progress.isCompleted || progress.rewardClaimed) {
      return false;
    }

    final challenge = await database.getDailyChallengeById(challengeId);
    if (challenge == null) return false;

    // 更新奖励领取状态
    await database.updateUserChallengeProgress(
      UserChallengeProgressesCompanion(
        id: Value(progress.id),
        rewardClaimed: Value(true),
        rewardClaimedAt: Value(DateTime.now()),
      ),
    );

    // 发放奖励到游戏化系统
    try {
      await gamificationService.addExperience(challenge.expReward);
      await gamificationService.addPoints(challenge.pointsReward);
    } catch (e) {
      // 奖励发放失败不影响领取状态更新
      print('挑战奖励发放失败: $e');
    }

    return true;
  }

  // ==================== 每周挑战管理 ====================

  /// 生成本周挑战
  Future<List<WeeklyChallenge>> generateThisWeekChallenges() async {
    final now = DateTime.now();
    final weekNumber = _getWeekNumber(now);
    final year = now.year;
    final weekKey = '$year-W$weekNumber';

    // 检查本周是否已有挑战
    final existing = await database.getWeeklyChallengesByWeekKey(weekKey);
    if (existing.isNotEmpty) {
      return existing;
    }

    // 生成新挑战
    final challengeDefinitions = ChallengeDefinitions.getRandomWeeklyChallenges();
    final challenges = <WeeklyChallenge>[];

    for (final definition in challengeDefinitions) {
      final id = await database.into(database.weeklyChallenges).insert(
            definition.toDatabaseEntity(weekNumber, year),
          );
      final challenge = await database.getWeeklyChallengeById(id);
      if (challenge != null) {
        challenges.add(challenge);

        // 创建对应的进度记录
        await database.into(database.userWeeklyChallengeProgresses).insert(
              UserWeeklyChallengeProgressesCompanion.insert(
                weeklyChallengeId: id,
                weekNumber: weekNumber,
                year: year,
                weekKey: weekKey,
                currentCount: Value(0),
                isCompleted: Value(false),
                rewardClaimed: Value(false),
              ),
            );
      }
    }

    return challenges;
  }

  /// 获取本周挑战（含进度）
  Future<List<Map<String, dynamic>>> getThisWeekChallengesWithProgress() async {
    final now = DateTime.now();
    final weekNumber = _getWeekNumber(now);
    final year = now.year;
    final weekKey = '$year-W$weekNumber';

    final challenges = await database.getWeeklyChallengesByWeekKey(weekKey);
    final result = <Map<String, dynamic>>[];

    for (final challenge in challenges) {
      // 为每个挑战获取独立的进度记录
      final progress = await database.getUserWeeklyChallengeProgressByChallengeId(challenge.id);

      result.add({
        'challenge': challenge,
        'progress': progress,
        'progressPercent': progress != null
            ? (progress.currentCount / challenge.targetCount * 100).clamp(0.0, 100.0)
            : 0.0,
      });
    }

    return result;
  }

  /// 更新每周挑战进度
  Future<bool> updateWeeklyChallengeProgress(
    ChallengeType type,
    int countIncrement, {
    int? minutesIncrement,
  }) async {
    final now = DateTime.now();
    final weekNumber = _getWeekNumber(now);
    final year = now.year;
    final weekKey = '$year-W$weekNumber';

    final challenges = await database.getWeeklyChallengesByWeekKey(weekKey);

    bool anyUpdated = false;

    for (final challenge in challenges) {
      if (challenge.type != type.value) continue;

      // 为每个挑战获取独立的进度记录
      final progress = await database.getUserWeeklyChallengeProgressByChallengeId(challenge.id);

      if (progress == null || progress.isCompleted) continue;

      int newCount = progress.currentCount + countIncrement;
      bool isCompleted = false;

      // 特殊处理：总时长类挑战
      if (type == ChallengeType.totalMinutes && minutesIncrement != null) {
        newCount = progress.currentCount + minutesIncrement;
      }

      if (newCount >= challenge.targetCount) {
        newCount = challenge.targetCount;
        isCompleted = true;
      }

      await database.updateUserWeeklyChallengeProgress(
        UserWeeklyChallengeProgressesCompanion(
          id: Value(progress.id),
          currentCount: Value(newCount),
          isCompleted: Value(isCompleted),
          completedAt: isCompleted ? Value(DateTime.now()) : Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );

      anyUpdated = true;
    }

    return anyUpdated;
  }

  /// 领取每周挑战奖励
  Future<bool> claimWeeklyChallengeReward(int challengeId) async {
    final now = DateTime.now();
    final weekNumber = _getWeekNumber(now);
    final year = now.year;
    final weekKey = '$year-W$weekNumber';

    final progress = await database.getUserWeeklyChallengeProgressByChallengeId(challengeId);

    if (progress == null || !progress.isCompleted || progress.rewardClaimed) {
      return false;
    }

    final challenge = await database.getWeeklyChallengeById(challengeId);
    if (challenge == null) return false;

    // 更新奖励领取状态
    await database.updateUserWeeklyChallengeProgress(
      UserWeeklyChallengeProgressesCompanion(
        id: Value(progress.id),
        rewardClaimed: Value(true),
        rewardClaimedAt: Value(DateTime.now()),
      ),
    );

    // 发放奖励到游戏化系统
    try {
      await gamificationService.addExperience(challenge.expReward);
      await gamificationService.addPoints(challenge.pointsReward);
    } catch (e) {
      // 奖励发放失败不影响领取状态更新
      print('每周挑战奖励发放失败: $e');
    }

    return true;
  }

  // ==================== 工具方法 ====================

  /// 获取周数
  int _getWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final weekNumber = ((dayOfYear - date.weekday + 10) / 7).floor();
    return weekNumber;
  }

  /// 获取距离下次刷新的时间
  Duration getTimeUntilNextRefresh() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// 获取本周剩余天数
  int getDaysUntilWeekEnd() {
    final now = DateTime.now();
    return DateTime.daysPerWeek - now.weekday;
  }

  // ==================== 自动刷新机制 ====================

  /// 初始化自动刷新定时器
  void initAutoRefresh() {
    _stopTimers();

    // 每日0点刷新定时器
    _initDailyRefreshTimer();

    // 每周一刷新定时器
    _initWeeklyRefreshTimer();
  }

  /// 停止所有定时器
  void _stopTimers() {
    _dailyRefreshTimer?.cancel();
    _weeklyRefreshTimer?.cancel();
    _dailyRefreshTimer = null;
    _weeklyRefreshTimer = null;
  }

  /// 初始化每日刷新定时器
  void _initDailyRefreshTimer() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final initialDelay = tomorrow.difference(now);

    // 首次延迟到明天0点
    _dailyRefreshTimer = Timer(initialDelay, () {
      // 生成新的每日挑战
      generateTodayChallenges();
      // 之后每24小时执行一次
      _dailyRefreshTimer = Timer.periodic(const Duration(days: 1), (_) {
        generateTodayChallenges();
      });
    });
  }

  /// 初始化每周刷新定时器
  void _initWeeklyRefreshTimer() {
    final now = DateTime.now();
    final nextMonday = _getNextMonday(now);
    final initialDelay = nextMonday.difference(now);

    // 首次延迟到下周一0点
    _weeklyRefreshTimer = Timer(initialDelay, () {
      // 生成新的每周挑战
      generateThisWeekChallenges();
      // 之后每7天执行一次
      _weeklyRefreshTimer = Timer.periodic(const Duration(days: 7), (_) {
        generateThisWeekChallenges();
      });
    });
  }

  /// 获取下周一的日期
  DateTime _getNextMonday(DateTime date) {
    final daysUntilMonday = (DateTime.monday - date.weekday + 7) % 7;
    if (daysUntilMonday == 0) {
      // 今天是周一，返回下周一
      return DateTime(date.year, date.month, date.day + 7);
    }
    final nextMonday = date.add(Duration(days: daysUntilMonday));
    return DateTime(nextMonday.year, nextMonday.month, nextMonday.day);
  }

  /// 销毁服务，清理定时器
  void dispose() {
    _stopTimers();
  }

  // ==================== 挑战进度检测（供其他模块调用）====================

  /// 运动完成时调用，更新相关挑战进度
  Future<void> onWorkoutCompleted({int durationMinutes = 0}) async {
    // 更新每日运动挑战
    await updateChallengeProgress(ChallengeType.workout, 1);
    // 更新运动时长挑战
    if (durationMinutes > 0) {
      await updateChallengeProgress(ChallengeType.totalMinutes, 0, minutesIncrement: durationMinutes);
    }
    // 更新每周挑战
    await updateWeeklyChallengeProgress(ChallengeType.workout, 1);
    if (durationMinutes > 0) {
      await updateWeeklyChallengeProgress(ChallengeType.totalMinutes, 0, minutesIncrement: durationMinutes);
    }
    // 更新连续打卡挑战
    await _updateStreakChallenge();
  }

  /// 笔记创建时调用，更新相关挑战进度
  Future<void> onNoteCreated() async {
    await updateChallengeProgress(ChallengeType.note, 1);
    await updateWeeklyChallengeProgress(ChallengeType.note, 1);
    await _updateStreakChallenge();
  }

  /// 计划任务完成时调用，更新相关挑战进度
  Future<void> onPlanTaskCompleted() async {
    await updateChallengeProgress(ChallengeType.plan, 1);
    await updateWeeklyChallengeProgress(ChallengeType.plan, 1);
    await _updateStreakChallenge();
  }

  /// 更新连续打卡挑战进度
  Future<void> _updateStreakChallenge() async {
    final now = DateTime.now();
    final weekNumber = _getWeekNumber(now);
    final year = now.year;
    final weekKey = '$year-W$weekNumber';

    // 获取本周连续打卡挑战
    final challenges = await database.getWeeklyChallengesByWeekKey(weekKey);
    final streakChallenges = challenges.where((c) => c.type == ChallengeType.streak.value);

    for (final challenge in streakChallenges) {
      final progress = await database.getUserWeeklyChallengeProgressByChallengeId(challenge.id);
      if (progress == null || progress.isCompleted) continue;

      // 获取游戏化服务的连续天数
      final currentStreak = await gamificationService.getCurrentStreak();
      final newCount = currentStreak.clamp(0, challenge.targetCount);
      final isCompleted = newCount >= challenge.targetCount;

      await database.updateUserWeeklyChallengeProgress(
        UserWeeklyChallengeProgressesCompanion(
          id: Value(progress.id),
          currentCount: Value(newCount),
          isCompleted: Value(isCompleted),
          completedAt: isCompleted ? Value(DateTime.now()) : Value.absent(),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}

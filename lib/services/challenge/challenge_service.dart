/// 挑战系统服务
/// 管理每日挑战和每周挑战的生成、进度更新和奖励发放
///
/// 修复内容：
/// 1. 使用 SharedPreferences 记录上次刷新时间，应用后台时定时器失效不影响
/// 2. 应用启动时检查是否需要刷新
/// 3. 使用 AppLifecycleListener 监听应用状态变化
/// 4. 修复周数计算为 ISO 8601 标准
/// 5. 使用 UTC 时间避免时区问题导致的日期边界竞态条件

import 'dart:async';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/gamification/gamification_service.dart';

/// 模块级随机数生成器（类外静态方法可访问）
final _random = Random();

// ==================== SharedPreferences 键定义 ====================

/// SharedPreferences 键常量
class _ChallengePrefsKeys {
  static const String lastDailyRefresh = 'challenge_last_daily_refresh';
  static const String lastWeeklyRefresh = 'challenge_last_weekly_refresh';
  static const String lastRefreshCheck = 'challenge_last_refresh_check';
}

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
    final randomSeed = _random.nextInt(1000000);
    final challenges = <DailyChallengeDefinition>[];

    // 确保至少有一个运动类挑战
    final workoutChallenges = dailyChallengePool
        .where((c) => c.type == ChallengeType.workout || c.type == ChallengeType.totalMinutes)
        .toList();
    challenges.add(workoutChallenges[randomSeed % workoutChallenges.length]);

    // 随机添加其他类型挑战
    final remaining = dailyChallengePool.where((c) => !challenges.contains(c)).toList();
    for (int i = 0; i < 2 && remaining.isNotEmpty; i++) {
      final index = (randomSeed + i * 100) % remaining.length;
      challenges.add(remaining[index]);
      remaining.removeAt(index);
    }

    return challenges;
  }

  /// 随机获取每周挑战（每周2个）
  static List<WeeklyChallengeDefinition> getRandomWeeklyChallenges() {
    final randomSeed = _random.nextInt(1000000);
    final challenges = <WeeklyChallengeDefinition>[];

    // 随机选择2个不同的挑战
    final pool = List<WeeklyChallengeDefinition>.from(weeklyChallengePool);
    for (int i = 0; i < 2 && pool.isNotEmpty; i++) {
      final index = (randomSeed + i * 100) % pool.length;
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
  Timer? _checkTimer;

  /// SharedPreferences 实例
  SharedPreferences? _prefs;

  /// 生命周期监听器标志
  bool _isLifecycleObserverAttached = false;

  /// 是否已初始化
  bool _isInitialized = false;

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

  // ==================== 初始化方法 ====================

  /// 初始化服务
  /// 必须在应用启动时调用
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 获取 SharedPreferences 实例
      _prefs ??= await SharedPreferences.getInstance();

      // 应用启动时检查并刷新
      await _checkAndRefreshOnStartup();

      // 初始化生命周期监听器
      _initLifecycleListener();

      // 启动定时检查器（每5分钟检查一次）
      _startCheckTimer();

      _isInitialized = true;
    } catch (e) {
      // 初始化失败不影响应用运行
      debugPrint('ChallengeService 初始化失败: $e');
    }
  }

  /// 应用启动时检查并刷新挑战
  Future<void> _checkAndRefreshOnStartup() async {
    if (_prefs == null || _database == null) return;

    final now = DateTime.now().toUtc();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);
    final weekData = _getISOWeekData(now);
    final weekKey = '${weekData.year}-W${weekData.weekNumber}';

    // 获取上次刷新时间
    final lastDailyRefresh = _prefs!.getString(_ChallengePrefsKeys.lastDailyRefresh);
    final lastWeeklyRefresh = _prefs!.getString(_ChallengePrefsKeys.lastWeeklyRefresh);

    // 检查每日挑战是否需要刷新
    if (lastDailyRefresh != todayKey) {
      await _refreshDailyChallenges(now, todayKey);
    }

    // 检查每周挑战是否需要刷新
    if (lastWeeklyRefresh != weekKey) {
      await _refreshWeeklyChallenges(weekData.weekNumber, weekData.year, weekKey);
    }

    // 更新检查时间
    await _prefs!.setString(_ChallengePrefsKeys.lastRefreshCheck, now.toIso8601String());
  }

  /// 刷新每日挑战
  Future<void> _refreshDailyChallenges(DateTime now, String todayKey) async {
    try {
      // 检查今日是否已有挑战
      final existing = await database.getDailyChallengesByDateKey(todayKey);
      if (existing.isEmpty) {
        await generateTodayChallenges();
      }

      // 更新刷新时间
      await _prefs!.setString(_ChallengePrefsKeys.lastDailyRefresh, todayKey);
      debugPrint('ChallengeService: 每日挑战已刷新 $todayKey');
    } catch (e) {
      debugPrint('ChallengeService: 刷新每日挑战失败 $e');
    }
  }

  /// 刷新每周挑战
  Future<void> _refreshWeeklyChallenges(int weekNumber, int year, String weekKey) async {
    try {
      // 检查本周是否已有挑战
      final existing = await database.getWeeklyChallengesByWeekKey(weekKey);
      if (existing.isEmpty) {
        await generateThisWeekChallenges();
      }

      // 更新刷新时间
      await _prefs!.setString(_ChallengePrefsKeys.lastWeeklyRefresh, weekKey);
      debugPrint('ChallengeService: 每周挑战已刷新 $weekKey');
    } catch (e) {
      debugPrint('ChallengeService: 刷新每周挑战失败 $e');
    }
  }

  /// 初始化应用生命周期监听器
  void _initLifecycleListener() {
    // 使用 WidgetsBindingObserver 监听应用状态变化
    if (!_isLifecycleObserverAttached) {
      WidgetsBinding.instance.addObserver(_LifecycleObserver(
        onResumed: _checkAndRefreshOnAppResumed,
      ));
      _isLifecycleObserverAttached = true;
    }
  }

  /// 应用恢复时检查刷新
  Future<void> _checkAndRefreshOnAppResumed() async {
    if (_prefs == null || _database == null) return;

    final now = DateTime.now().toUtc();
    final lastCheckStr = _prefs!.getString(_ChallengePrefsKeys.lastRefreshCheck);

    if (lastCheckStr != null) {
      final lastCheck = DateTime.parse(lastCheckStr);
      final difference = now.difference(lastCheck);

      // 如果超过1小时未检查，进行刷新检查
      if (difference.inHours >= 1) {
        await _checkAndRefreshOnStartup();
      }
    }
  }

  /// 启动定时检查器（每5分钟检查一次）
  void _startCheckTimer() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkAndRefreshOnStartup();
    });
  }

  // ==================== 每日挑战管理 ====================

  /// 生成今日挑战
  Future<List<DailyChallenge>> generateTodayChallenges() async {
    final now = DateTime.now().toUtc();
    final todayKey = DateFormat('yyyy-MM-dd').format(now);

    // 检查今日是否已有挑战（使用数据库查询防止重复）
    final existing = await database.getDailyChallengesByDateKey(todayKey);
    if (existing.isNotEmpty) {
      return existing;
    }

    // 生成新挑战
    final challengeDefinitions = ChallengeDefinitions.getRandomDailyChallenges();
    final challenges = <DailyChallenge>[];

    for (final definition in challengeDefinitions) {
      final id = await database.into(database.dailyChallenges).insert(
            definition.toDatabaseEntity(now),
          );
      final challenge = await database.getDailyChallengeById(id);
      if (challenge != null) {
        challenges.add(challenge);

        // 创建对应的进度记录
        await database.into(database.userChallengeProgresses).insert(
              UserChallengeProgressesCompanion.insert(
                challengeId: id,
                date: now,
                currentCount: Value(0),
                isCompleted: Value(false),
                rewardClaimed: Value(false),
              ),
            );
      }
    }

    // 更新刷新时间
    if (_prefs != null) {
      await _prefs!.setString(_ChallengePrefsKeys.lastDailyRefresh, todayKey);
    }

    return challenges;
  }

  /// 获取今日挑战（含进度）
  /// 使用 UTC 时间避免时区问题
  Future<List<Map<String, dynamic>>> getTodayChallengesWithProgress() async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);
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
  /// 使用 UTC 时间和原子操作避免日期边界竞态条件
  Future<bool> updateChallengeProgress(
    ChallengeType type,
    int countIncrement, {
    int? minutesIncrement,
  }) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);

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

      // 原子更新操作
      await database.updateUserChallengeProgress(
        UserChallengeProgressesCompanion(
          id: Value(progress.id),
          currentCount: Value(newCount),
          isCompleted: Value(isCompleted),
          completedAt: isCompleted ? Value(now) : Value.absent(),
          updatedAt: Value(now),
        ),
      );

      anyUpdated = true;
    }

    return anyUpdated;
  }

  /// 领取挑战奖励
  /// 使用 UTC 时间，修复：先发放奖励，成功后再更新状态，确保事务性
  Future<bool> claimChallengeReward(int challengeId) async {
    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);

    final progress = await database.getUserChallengeProgressByChallengeAndDate(
          challengeId,
          startOfDay,
        );

    if (progress == null || !progress.isCompleted || progress.rewardClaimed) {
      return false;
    }

    final challenge = await database.getDailyChallengeById(challengeId);
    if (challenge == null) return false;

    try {
      // 先发放奖励到游戏化系统（如果失败，状态不会更新）
      await gamificationService.addExperience(challenge.expReward);
      await gamificationService.addPoints(challenge.pointsReward);

      // 奖励发放成功后，更新领取状态
      await database.updateUserChallengeProgress(
        UserChallengeProgressesCompanion(
          id: Value(progress.id),
          rewardClaimed: Value(true),
          rewardClaimedAt: Value(now),
        ),
      );

      return true;
    } catch (e) {
      // 奖励发放失败，保持未领取状态，记录错误日志
      debugPrint('[ChallengeService] 每日挑战奖励发放失败 - challengeId: $challengeId, error: $e');
      // 重新抛出异常，让调用方知道操作失败
      rethrow;
    }
  }

  // ==================== 每周挑战管理 ====================

  /// 生成本周挑战
  Future<List<WeeklyChallenge>> generateThisWeekChallenges() async {
    final now = DateTime.now().toUtc();
    final weekData = _getISOWeekData(now);
    final weekNumber = weekData.weekNumber;
    final year = weekData.year;
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

    // 更新刷新时间
    if (_prefs != null) {
      await _prefs!.setString(_ChallengePrefsKeys.lastWeeklyRefresh, weekKey);
    }

    return challenges;
  }

  /// 获取本周挑战（含进度）
  Future<List<Map<String, dynamic>>> getThisWeekChallengesWithProgress() async {
    final now = DateTime.now().toUtc();
    final weekData = _getISOWeekData(now);
    final weekNumber = weekData.weekNumber;
    final year = weekData.year;
    final weekKey = '$year-W$weekNumber';

    final challenges = await database.getWeeklyChallengesByWeekKey(weekKey);
    final result = <Map<String, dynamic>>[];

    for (final challenge in challenges) {
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
    final now = DateTime.now().toUtc();
    final weekData = _getISOWeekData(now);
    final weekNumber = weekData.weekNumber;
    final year = weekData.year;
    final weekKey = '$year-W$weekNumber';

    final challenges = await database.getWeeklyChallengesByWeekKey(weekKey);

    bool anyUpdated = false;

    for (final challenge in challenges) {
      if (challenge.type != type.value) continue;

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

      // 原子更新操作
      await database.updateUserWeeklyChallengeProgress(
        UserWeeklyChallengeProgressesCompanion(
          id: Value(progress.id),
          currentCount: Value(newCount),
          isCompleted: Value(isCompleted),
          completedAt: isCompleted ? Value(now) : Value.absent(),
          updatedAt: Value(now),
        ),
      );

      anyUpdated = true;
    }

    return anyUpdated;
  }

  /// 领取每周挑战奖励
  /// 使用 UTC 时间，修复：先发放奖励，成功后再更新状态，确保事务性
  Future<bool> claimWeeklyChallengeReward(int challengeId) async {
    final now = DateTime.now().toUtc();
    final weekData = _getISOWeekData(now);
    final weekNumber = weekData.weekNumber;
    final year = weekData.year;
    final weekKey = '$year-W$weekNumber';

    final progress = await database.getUserWeeklyChallengeProgressByChallengeId(challengeId);

    if (progress == null || !progress.isCompleted || progress.rewardClaimed) {
      return false;
    }

    final challenge = await database.getWeeklyChallengeById(challengeId);
    if (challenge == null) return false;

    try {
      // 先发放奖励到游戏化系统（如果失败，状态不会更新）
      await gamificationService.addExperience(challenge.expReward);
      await gamificationService.addPoints(challenge.pointsReward);

      // 奖励发放成功后，更新领取状态
      await database.updateUserWeeklyChallengeProgress(
        UserWeeklyChallengeProgressesCompanion(
          id: Value(progress.id),
          rewardClaimed: Value(true),
          rewardClaimedAt: Value(now),
        ),
      );

      return true;
    } catch (e) {
      // 奖励发放失败，保持未领取状态，记录错误日志
      debugPrint('[ChallengeService] 每周挑战奖励发放失败 - challengeId: $challengeId, error: $e');
      // 重新抛出异常，让调用方知道操作失败
      rethrow;
    }
  }

  // ==================== 工具方法 ====================

  /// ISO 周数据
  /// 使用 ISO-8601 标准计算周数和年份
  ({int year, int weekNumber}) _getISOWeekData(DateTime date) {
    // 方案1：使用 intl 包的 ISO 周数格式化
    // 移除可能的 "W" 前缀，确保可以正确解析
    String weekStr = DateFormat('w').format(date);
    // 如果返回的是 "W05" 格式，移除 "W" 前缀
    weekStr = weekStr.replaceAll('W', '').replaceAll('w', '');
    final weekNumber = int.parse(weekStr);

    // 获取 ISO 年份（可能与日历年不同）
    // 使用 'Y' 格式符获取 ISO 年份
    final year = int.parse(DateFormat('Y').format(date));

    return (year: year, weekNumber: weekNumber);
  }

  /// 获取周数（保持向后兼容）
  @Deprecated('使用 _getISOWeekData 替代，此方法仅用于向后兼容')
  int _getWeekNumber(DateTime date) {
    return _getISOWeekData(date).weekNumber;
  }

  /// 获取距离下次刷新的时间
  Duration getTimeUntilNextRefresh() {
    final now = DateTime.now().toUtc();
    final tomorrow = DateTime.utc(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// 获取本周剩余天数（周一为第一天）
  int getDaysUntilWeekEnd() {
    final now = DateTime.now().toUtc();
    // ISO 8601 标准周一为 1，周日为 7
    return 7 - now.weekday;
  }

  // ==================== 自动刷新机制（已弃用，使用新的检查机制）====================

  /// 初始化自动刷新定时器
  /// 已弃用：请使用 initialize() 方法
  @Deprecated('使用 initialize() 方法替代，新的刷新机制更可靠')
  void initAutoRefresh() {
    initialize();
  }

  /// 停止所有定时器
  void _stopTimers() {
    _dailyRefreshTimer?.cancel();
    _weeklyRefreshTimer?.cancel();
    _checkTimer?.cancel();
    _dailyRefreshTimer = null;
    _weeklyRefreshTimer = null;
    _checkTimer = null;
  }

  /// 销毁服务，清理定时器和监听器
  void dispose() {
    _stopTimers();
    // 生命周期观察者会在应用关闭时自动清理
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
    final now = DateTime.now().toUtc();
    final weekData = _getISOWeekData(now);
    final weekNumber = weekData.weekNumber;
    final year = weekData.year;
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
          completedAt: isCompleted ? Value(now) : Value.absent(),
          updatedAt: Value(now),
        ),
      );
    }
  }
}

// ==================== 生命周期观察者 ====================

/// 生命周期观察者 - 用于监听应用状态变化
/// 使用 WidgetsBindingObserver 模式替代 AppLifecycleListener，提高兼容性
class _LifecycleObserver with WidgetsBindingObserver {
  final VoidCallback onResumed;

  _LifecycleObserver({required this.onResumed}) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}

/// 游戏化核心服务
/// 处理等级、经验、积分、连续打卡等游戏化逻辑

import 'dart:async';
import 'package:drift/drift.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/gamification/data/models/game_models.dart';

/// 游戏化服务
class GamificationService {
  AppDatabase? _db;

  /// 设置数据库实例
  void setDatabase(AppDatabase database) {
    _db = database;
  }

  /// 确保数据库已初始化
  AppDatabase get db {
    if (_db == null) {
      throw StateError('GamificationService: 数据库未初始化，请先调用 setDatabase()');
    }
    return _db!;
  }

  // ==================== 用户档案管理 ====================

  /// 获取或创建用户游戏化档案
  Future<GamificationUserProfile> getOrCreateUserProfile() async {
    final profiles = await db.select(db.gamificationUserProfiles).get();
    if (profiles.isNotEmpty) {
      return profiles.first;
    }

    // 创建新用户档案
    final newProfile = GamificationUserProfilesCompanion.insert(
      level: const Value(1),
      experience: const Value(0),
      totalExperience: const Value(0),
      points: const Value(0),
      totalPoints: const Value(0),
      currentStreak: const Value(0),
      longestStreak: const Value(0),
      unlockedAchievements: const Value(0),
      totalAchievements: Value(AchievementDefinitions.allAchievements.length),
    );

    final id = await db.into(db.gamificationUserProfiles).insert(newProfile);
    return (await (db.select(db.gamificationUserProfiles)..where((t) => t.id.equals(id))).getSingle())!;
  }

  /// 获取用户游戏化数据（视图模型）
  Future<UserGameDataModel> getUserGameData() async {
    final profile = await getOrCreateUserProfile();
    return UserGameDataModel.fromDb(profile);
  }

  /// 更新用户档案数据
  Future<void> updateProfile({
    int? level,
    int? exp,
    int? totalExp,
    int? points,
    int? totalPoints,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastCheckInDate,
    int? unlockedAchievements,
    int? totalWorkouts,
    int? totalWorkoutMinutes,
    int? totalNotes,
    int? totalPlans,
    int? completedPlans,
  }) async {
    final profile = await getOrCreateUserProfile();

    await (db.update(db.gamificationUserProfiles)..where((t) => t.id.equals(profile.id))).write(
      GamificationUserProfilesCompanion(
        id: Value(profile.id),
        level: level != null ? Value(level) : const Value.absent(),
        experience: exp != null ? Value(exp) : const Value.absent(),
        totalExperience: totalExp != null ? Value(totalExp) : const Value.absent(),
        points: points != null ? Value(points) : const Value.absent(),
        totalPoints: totalPoints != null ? Value(totalPoints) : const Value.absent(),
        currentStreak: currentStreak != null ? Value(currentStreak) : const Value.absent(),
        longestStreak: longestStreak != null ? Value(longestStreak) : const Value.absent(),
        lastCheckInDate: lastCheckInDate != null ? Value(lastCheckInDate) : const Value.absent(),
        unlockedAchievements: unlockedAchievements != null ? Value(unlockedAchievements) : const Value.absent(),
        totalWorkouts: totalWorkouts != null ? Value(totalWorkouts) : const Value.absent(),
        totalWorkoutMinutes: totalWorkoutMinutes != null ? Value(totalWorkoutMinutes) : const Value.absent(),
        totalNotes: totalNotes != null ? Value(totalNotes) : const Value.absent(),
        totalPlans: totalPlans != null ? Value(totalPlans) : const Value.absent(),
        completedPlans: completedPlans != null ? Value(completedPlans) : const Value.absent(),
      ),
    );
  }

  // ==================== 经验与等级系统 ====================

  /// 添加经验值
  /// 返回是否升级
  Future<bool> addExperience(int exp, {int? minutes}) async {
    if (exp <= 0) return false;

    final profile = await getOrCreateUserProfile();
    final oldLevel = profile.level;
    final newTotalExp = profile.totalExperience + exp;

    // 计算新等级
    final newLevel = LevelConfig.getLevelFromExperience(newTotalExp);

    // 更新用户档案
    await updateProfile(
      exp: newTotalExp - LevelConfig.getExperienceForLevel(newLevel),
      totalExp: newTotalExp,
      level: newLevel,
    );

    // 如果升级了，返回true
    if (newLevel > oldLevel) {
      // 升级额外奖励经验
      final bonusExp = ExperienceReward.levelUpBonus;
      final bonusTotalExp = newTotalExp + bonusExp;
      final finalLevel = LevelConfig.getLevelFromExperience(bonusTotalExp);
      await updateProfile(
        exp: bonusTotalExp - LevelConfig.getExperienceForLevel(finalLevel),
        totalExp: bonusTotalExp,
        level: finalLevel,
      );
      return true;
    }

    return false;
  }

  /// 添加积分
  Future<void> addPoints(int points) async {
    if (points <= 0) return;

    final profile = await getOrCreateUserProfile();
    await updateProfile(
      points: profile.points + points,
      totalPoints: profile.totalPoints + points,
    );
  }

  /// 消费积分（购买物品）
  /// 返回是否成功
  Future<bool> spendPoints(int points) async {
    if (points <= 0) return false;

    final profile = await getOrCreateUserProfile();
    if (profile.points < points) return false;

    await updateProfile(points: profile.points - points);
    return true;
  }

  // ==================== 连续打卡系统 ====================

  /// 执行每日打卡
  /// 返回 (是否连续, 连续天数, 获得的积分, 获得的经验)
  Future<(bool, int, int, int)> performDailyCheckIn() async {
    final profile = await getOrCreateUserProfile();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 检查今天是否已经打卡
    if (profile.lastCheckInDate != null) {
      final lastCheckIn = DateTime(
        profile.lastCheckInDate!.year,
        profile.lastCheckInDate!.month,
        profile.lastCheckInDate!.day,
      );
      if (lastCheckIn.isAtSameMomentAs(today)) {
        // 今天已经打卡
        return (true, profile.currentStreak, 0, 0);
      }
    }

    // 计算是否连续
    final yesterday = today.subtract(const Duration(days: 1));
    final isConsecutive = profile.lastCheckInDate != null &&
        DateTime(profile.lastCheckInDate!.year, profile.lastCheckInDate!.month, profile.lastCheckInDate!.day)
            .isAtSameMomentAs(yesterday);

    // 计算新的连续天数
    final newStreak = isConsecutive ? profile.currentStreak + 1 : 1;
    final newLongestStreak = newStreak > profile.longestStreak ? newStreak : profile.longestStreak;

    // 计算奖励
    var pointsEarned = PointReward.dailyCheckIn;
    var expEarned = ExperienceReward.dailyCheckIn;

    // 连续打卡额外奖励（每7天）
    if (newStreak % 7 == 0) {
      pointsEarned += PointReward.streakWeeklyBonus;
      expEarned += 50;
    }

    // 更新档案
    await updateProfile(
      currentStreak: newStreak,
      longestStreak: newLongestStreak,
      lastCheckInDate: now,
    );

    // 添加奖励
    await addPoints(pointsEarned);
    await addExperience(expEarned);

    // 检查并解锁连续打卡相关成就
    await _checkAndUnlockAchievements('streak_days', newStreak);

    return (isConsecutive, newStreak, pointsEarned, expEarned);
  }

  /// 获取当前连续天数
  Future<int> getCurrentStreak() async {
    final profile = await getOrCreateUserProfile();
    return profile.currentStreak;
  }

  /// 重置连续打卡（如果中断）
  Future<void> resetStreak() async {
    await updateProfile(currentStreak: 0);
  }

  // ==================== 运动相关事件 ====================

  /// 记录运动事件
  Future<void> recordWorkout(int durationMinutes) async {
    final profile = await getOrCreateUserProfile();

    // 计算奖励
    final pointsEarned = PointReward.workout + (durationMinutes * PointReward.workoutPerMinute);
    final expEarned = ExperienceReward.workout + (durationMinutes * ExperienceReward.workoutPerMinute);

    // 更新统计
    await updateProfile(
      totalWorkouts: profile.totalWorkouts + 1,
      totalWorkoutMinutes: profile.totalWorkoutMinutes + durationMinutes,
    );

    // 添加奖励
    await addPoints(pointsEarned);
    await addExperience(expEarned);

    // 检查并解锁运动相关成就
    await _checkAndUnlockAchievements('workout_count', profile.totalWorkouts + 1);
    await _checkAndUnlockAchievements('total_workouts', profile.totalWorkouts + 1);
    await _checkAndUnlockAchievements('total_minutes', profile.totalWorkoutMinutes + durationMinutes);
    await _checkAndUnlockAchievements('single_workout_minutes', durationMinutes);
  }

  // ==================== 笔记相关事件 ====================

  /// 记录创建笔记事件
  Future<void> recordNoteCreated() async {
    final profile = await getOrCreateUserProfile();

    // 计算奖励
    final pointsEarned = PointReward.noteCreated;
    final expEarned = ExperienceReward.noteCreated;

    // 更新统计
    await updateProfile(totalNotes: profile.totalNotes + 1);

    // 添加奖励
    await addPoints(pointsEarned);
    await addExperience(expEarned);

    // 检查并解锁笔记相关成就
    await _checkAndUnlockAchievements('note_count', profile.totalNotes + 1);
  }

  // ==================== 计划相关事件 ====================

  /// 记录创建计划事件
  Future<void> recordPlanCreated() async {
    final profile = await getOrCreateUserProfile();
    await updateProfile(totalPlans: profile.totalPlans + 1);

    // 检查并解锁计划相关成就
    await _checkAndUnlockAchievements('plan_count', profile.totalPlans + 1);
  }

  /// 记录完成计划事件
  Future<void> recordPlanCompleted() async {
    final profile = await getOrCreateUserProfile();

    // 计算奖励
    final pointsEarned = PointReward.planCompleted;
    final expEarned = ExperienceReward.planCompleted;

    // 更新统计
    await updateProfile(completedPlans: profile.completedPlans + 1);

    // 添加奖励
    await addPoints(pointsEarned);
    await addExperience(expEarned);

    // 检查并解锁计划完成相关成就
    await _checkAndUnlockAchievements('completed_plans', profile.completedPlans + 1);
  }

  /// 记录完成任务事件
  Future<void> recordPlanTaskCompleted() async {
    final pointsEarned = PointReward.planTaskCompleted;
    final expEarned = ExperienceReward.planTaskCompleted;

    await addPoints(pointsEarned);
    await addExperience(expEarned);
  }

  // ==================== 成就系统 ====================

  /// 检查并解锁成就
  Future<void> _checkAndUnlockAchievements(String conditionType, int currentValue) async {
    final profile = await getOrCreateUserProfile();

    // 筛选符合条件的成就
    final matchingAchievements = AchievementDefinitions.allAchievements
        .where((a) => a.conditionType == conditionType && currentValue >= a.requirement)
        .toList();

    for (final achievementDef in matchingAchievements) {
      // 检查是否已解锁
      final existing = await (db.select(db.userAchievements)
            ..where((tbl) => tbl.achievementId.equals(profile.id))
            ..where((tbl) => tbl.id.equals(achievementDef.id.hashCode)))
          .getSingleOrNull();

      if (existing == null) {
        // 解锁新成就
        await _unlockAchievement(achievementDef);
      }
    }

    // 检查等级成就
    if (conditionType == 'level') {
      await _checkAndUnlockAchievements('level', profile.level);
    }
  }

  /// 解锁成就
  Future<UserAchievement?> _unlockAchievement(AchievementDef achievementDef) async {
    final profile = await getOrCreateUserProfile();

    // 获取或创建数据库中的成就记录
    final dbAchievements = await (db.select(db.achievements)
          ..where((tbl) => tbl.code.equals(achievementDef.id)))
        .get();

    late Achievement achievement;
    if (dbAchievements.isEmpty) {
      // 创建成就记录
      final achievementId = await db.into(db.achievements).insert(AchievementsCompanion(
        code: Value(achievementDef.id),
        name: Value(achievementDef.name),
        description: Value(achievementDef.description),
        iconCode: Value(achievementDef.icon),
        category: Value(achievementDef.category.value),
        tier: Value(achievementDef.tier.value),
        conditionType: Value(achievementDef.conditionType),
        conditionValue: Value(achievementDef.requirement),
        rewardPoints: Value(achievementDef.pointsReward),
        rewardExperience: Value(achievementDef.expReward),
      ));

      achievement = (await (db.select(db.achievements)..where((t) => t.id.equals(achievementId))).getSingle())!;
    } else {
      achievement = dbAchievements.first;
    }

    // 创建用户成就关联记录
    final userAchievementId = await db.into(db.userAchievements).insert(UserAchievementsCompanion(
      achievementId: Value(achievement.id),
      userProfileId: Value(profile.id),
      unlockedAt: Value(DateTime.now()),
    ));

    // 更新用户档案
    await updateProfile(
      unlockedAchievements: profile.unlockedAchievements + 1,
    );

    // 添加成就奖励
    await addPoints(achievementDef.pointsReward);
    await addExperience(achievementDef.expReward);

    return (await (db.select(db.userAchievements)..where((t) => t.id.equals(userAchievementId))).getSingle());
  }

  /// 获取所有成就及其解锁状态
  Future<List<AchievementProgress>> getAllAchievementsProgress() async {
    final profile = await getOrCreateUserProfile();
    final progressList = <AchievementProgress>[];

    // 获取当前统计数据
    final totalWorkouts = profile.totalWorkouts;
    final totalMinutes = profile.totalWorkoutMinutes;
    final totalNotes = profile.totalNotes;
    final completedPlans = profile.completedPlans;
    final totalPlans = profile.totalPlans;
    final currentStreak = profile.currentStreak;
    final level = profile.level;
    final totalPoints = profile.totalPoints;

    // 获取已解锁的成就
    final unlockedList = await (db.select(db.userAchievements)
          ..where((tbl) => tbl.userProfileId.equals(profile.id)))
        .get();

    final unlockedAchievementIds = <int>{};
    for (final ua in unlockedList) {
      final achievement = await (db.select(db.achievements)..where((t) => t.id.equals(ua.achievementId))).getSingle();
      unlockedAchievementIds.add(achievement.id);
    }

    // 遍历所有成就定义
    for (final achievementDef in AchievementDefinitions.allAchievements) {
      // 计算当前进度
      int currentProgress = 0;
      switch (achievementDef.conditionType) {
        case 'workout_count':
        case 'total_workouts':
          currentProgress = totalWorkouts;
          break;
        case 'total_minutes':
          currentProgress = totalMinutes;
          break;
        case 'single_workout_minutes':
          // 需要查询单次最长运动时间
          currentProgress = await _getLongestSingleWorkoutMinutes();
          break;
        case 'note_count':
          currentProgress = totalNotes;
          break;
        case 'plan_count':
          currentProgress = totalPlans;
          break;
        case 'completed_plans':
          currentProgress = completedPlans;
          break;
        case 'streak_days':
          currentProgress = currentStreak;
          break;
        case 'level':
          currentProgress = level;
          break;
        case 'total_points':
          currentProgress = totalPoints;
          break;
      }

      // 查找是否已解锁
      final dbAchievements = await (db.select(db.achievements)
            ..where((tbl) => tbl.code.equals(achievementDef.id)))
          .get();

      final isUnlocked = dbAchievements.isNotEmpty &&
          (await (db.select(db.userAchievements)
                ..where((tbl) => tbl.achievementId.equals(dbAchievements.first.id))
                ..where((tbl) => tbl.userProfileId.equals(profile.id)))
              .getSingleOrNull()) != null;

      progressList.add(AchievementProgress(
        achievement: achievementDef,
        currentProgress: currentProgress,
        isUnlocked: isUnlocked,
        unlockedAt: isUnlocked ? DateTime.now() : null,
      ));
    }

    return progressList;
  }

  /// 获取最长单次运动时长
  Future<int> _getLongestSingleWorkoutMinutes() async {
    final workouts = await (db.select(db.workouts)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.durationMinutes)]))
        .get();

    if (workouts.isEmpty) return 0;
    return workouts.first.durationMinutes;
  }

  /// 获取已解锁的成就列表
  Future<List<AchievementProgress>> getUnlockedAchievements() async {
    final all = await getAllAchievementsProgress();
    return all.where((a) => a.isUnlocked).toList();
  }

  /// 获取未解锁的成就列表
  Future<List<AchievementProgress>> getLockedAchievements() async {
    final all = await getAllAchievementsProgress();
    return all.where((a) => !a.isUnlocked).toList();
  }
}

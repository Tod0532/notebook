// 用户反馈仓库
// 处理用户对动作/食材的反馈数据存储和查询
// 包含统一的异常处理

import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:thick_notepad/services/database/database.dart';

/// 用户反馈仓库异常类
class UserFeedbackRepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  UserFeedbackRepositoryException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'UserFeedbackRepositoryException: $message';
  }
}

/// 反馈类型枚举
enum FeedbackType {
  exercise('训练动作', 'exercise'),
  food('食材', 'food');

  final String displayName;
  final String value;

  const FeedbackType(this.displayName, this.value);

  static FeedbackType fromString(String value) {
    return FeedbackType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FeedbackType.exercise,
    );
  }
}

/// 反馈原因枚举 - 训练动作
enum ExerciseFeedbackReason {
  tooHard('太难了', 'too_hard'),
  tooEasy('太简单了', 'too_easy'),
  dislike('不喜欢这个动作', 'dislike'),
  noEquipment('没有相关器械', 'no_equipment'),
  injury('身体原因不适合', 'injury');

  final String displayName;
  final String value;

  const ExerciseFeedbackReason(this.displayName, this.value);

  static ExerciseFeedbackReason fromString(String value) {
    return ExerciseFeedbackReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ExerciseFeedbackReason.tooHard,
    );
  }
}

/// 反馈原因枚举 - 食材
enum FoodFeedbackReason {
  unavailable('买不到', 'unavailable'),
  tooHard('太难做', 'too_hard'),
  dislike('不喜欢吃', 'dislike'),
  allergy('过敏/不耐受', 'allergy'),
  tooExpensive('太贵了', 'too_expensive');

  final String displayName;
  final String value;

  const FoodFeedbackReason(this.displayName, this.value);

  static FoodFeedbackReason fromString(String value) {
    return FoodFeedbackReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FoodFeedbackReason.unavailable,
    );
  }
}

/// 用户反馈仓库
class UserFeedbackRepository {
  final AppDatabase _db;

  UserFeedbackRepository(this._db);

  // ==================== CRUD 操作 ====================

  /// 创建反馈记录
  Future<int> createFeedback({
    required FeedbackType feedbackType,
    required int itemId,
    required String itemType,
    required String reason,
    required String originalName,
    String? replacementName,
    int? userProfileId,
    String? notes,
  }) async {
    try {
      final entity = UserFeedbacksCompanion.insert(
        feedbackType: feedbackType.value,
        itemId: itemId,
        itemType: itemType,
        reason: reason,
        originalName: originalName,
        replacementName: drift.Value(replacementName),
        userProfileId: drift.Value(userProfileId),
        notes: drift.Value(notes),
      );
      return await _db.into(_db.userFeedbacks).insert(entity);
    } catch (e, st) {
      debugPrint('创建用户反馈失败: $e');
      throw UserFeedbackRepositoryException('创建用户反馈失败', e, st);
    }
  }

  /// 获取所有反馈
  Future<List<UserFeedback>> getAllFeedbacks() async {
    try {
      return await (_db.select(_db.userFeedbacks)
            ..orderBy([(f) => drift.OrderingTerm.asc(f.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取所有反馈失败: $e');
      throw UserFeedbackRepositoryException('获取所有反馈失败', e, st);
    }
  }

  /// 按用户画像获取反馈
  Future<List<UserFeedback>> getFeedbacksByProfile(int profileId) async {
    try {
      return await (_db.select(_db.userFeedbacks)
            ..where((f) => f.userProfileId.equals(profileId))
            ..orderBy([(f) => drift.OrderingTerm.asc(f.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取用户画像反馈失败: $e');
      throw UserFeedbackRepositoryException('获取用户画像反馈失败', e, st);
    }
  }

  /// 按反馈类型获取
  Future<List<UserFeedback>> getFeedbacksByType(FeedbackType type) async {
    try {
      return await (_db.select(_db.userFeedbacks)
            ..where((f) => f.feedbackType.equals(type.value))
            ..orderBy([(f) => drift.OrderingTerm.asc(f.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('按类型获取反馈失败: $e');
      throw UserFeedbackRepositoryException('按类型获取反馈失败', e, st);
    }
  }

  /// 按原因统计反馈数量
  Future<Map<String, int>> getFeedbackCountByReason({
    FeedbackType? type,
    int? userProfileId,
  }) async {
    try {
      final query = _db.select(_db.userFeedbacks);

      if (type != null) {
        query.where((f) => f.feedbackType.equals(type.value));
      }
      if (userProfileId != null) {
        query.where((f) => f.userProfileId.equals(userProfileId));
      }

      final feedbacks = await query.get();

      final Map<String, int> result = {};
      for (final f in feedbacks) {
        result[f.reason] = (result[f.reason] ?? 0) + 1;
      }
      return result;
    } catch (e, st) {
      debugPrint('统计反馈原因失败: $e');
      throw UserFeedbackRepositoryException('统计反馈原因失败', e, st);
    }
  }

  /// 获取最常被替换的项目（用于AI优化）
  Future<List<Map<String, dynamic>>> getMostReplacedItems({
    FeedbackType? type,
    int? userProfileId,
    int limit = 10,
  }) async {
    try {
      final query = _db.select(_db.userFeedbacks);

      if (type != null) {
        query.where((f) => f.feedbackType.equals(type.value));
      }
      if (userProfileId != null) {
        query.where((f) => f.userProfileId.equals(userProfileId));
      }

      final feedbacks = await query.get();

      // 统计每个原始名称的反馈次数
      final Map<String, Map<String, dynamic>> stats = {};
      for (final f in feedbacks) {
        final key = f.originalName;
        if (!stats.containsKey(key)) {
          stats[key] = {
            'name': f.originalName,
            'count': 0,
            'reasons': <String>[],
          };
        }
        stats[key]!['count'] = stats[key]!['count']! + 1;
        if (!stats[key]!['reasons'].contains(f.reason)) {
          stats[key]!['reasons'].add(f.reason);
        }
      }

      // 按数量排序
      final sorted = stats.values.toList()
        ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      return sorted.take(limit).toList();
    } catch (e, st) {
      debugPrint('获取最常替换项目失败: $e');
      throw UserFeedbackRepositoryException('获取最常替换项目失败', e, st);
    }
  }

  /// 获取最近的反馈
  Future<List<UserFeedback>> getRecentFeedbacks({
    FeedbackType? type,
    int? userProfileId,
    int limit = 20,
  }) async {
    try {
      final query = _db.select(_db.userFeedbacks);

      if (type != null) {
        query.where((f) => f.feedbackType.equals(type.value));
      }
      if (userProfileId != null) {
        query.where((f) => f.userProfileId.equals(userProfileId));
      }

      return await (query
            ..orderBy([(f) => drift.OrderingTerm.desc(f.createdAt)]))
          .get()
          .then((list) => list.take(limit).toList());
    } catch (e, st) {
      debugPrint('获取最近反馈失败: $e');
      throw UserFeedbackRepositoryException('获取最近反馈失败', e, st);
    }
  }

  /// 删除反馈记录
  Future<bool> deleteFeedback(int id) async {
    try {
      final result = await (_db.delete(_db.userFeedbacks)..where((tbl) => tbl.id.equals(id))).go();
      return result > 0;
    } catch (e, st) {
      debugPrint('删除反馈记录失败: $e');
      throw UserFeedbackRepositoryException('删除反馈记录失败', e, st);
    }
  }

  /// 清空用户的所有反馈
  Future<int> clearFeedbacksByProfile(int profileId) async {
    try {
      final items = await (_db.select(_db.userFeedbacks)
            ..where((f) => f.userProfileId.equals(profileId)))
          .get();

      int count = 0;
      for (final item in items) {
        final result = await (_db.delete(_db.userFeedbacks)..where((tbl) => tbl.id.equals(item.id))).go();
        if (result > 0) count++;
      }
      return count;
    } catch (e, st) {
      debugPrint('清空用户反馈失败: $e');
      throw UserFeedbackRepositoryException('清空用户反馈失败', e, st);
    }
  }

  // ==================== 辅助方法 ====================

  /// 获取用户偏好摘要（用于AI生成计划）
  Future<Map<String, dynamic>> getUserPreferenceSummary(int userProfileId) async {
    try {
      final feedbacks = await getFeedbacksByProfile(userProfileId);

      final Set<String> dislikedExercises = {};
      final Set<String> unavailableFoods = {};
      final Set<String> dislikedFoods = {};
      final Map<String, int> difficultyFeedback = {'too_hard': 0, 'too_easy': 0};

      for (final f in feedbacks) {
        if (f.feedbackType == 'exercise') {
          if (f.reason == 'dislike' || f.reason == 'injury') {
            dislikedExercises.add(f.originalName);
          }
          if (f.reason == 'too_hard') {
            difficultyFeedback['too_hard'] = difficultyFeedback['too_hard']! + 1;
          }
          if (f.reason == 'too_easy') {
            difficultyFeedback['too_easy'] = difficultyFeedback['too_easy']! + 1;
          }
        } else if (f.feedbackType == 'food') {
          if (f.reason == 'unavailable' || f.reason == 'too_expensive') {
            unavailableFoods.add(f.originalName);
          }
          if (f.reason == 'dislike' || f.reason == 'allergy') {
            dislikedFoods.add(f.originalName);
          }
        }
      }

      return {
        'disliked_exercises': dislikedExercises.toList(),
        'unavailable_foods': unavailableFoods.toList(),
        'disliked_foods': dislikedFoods.toList(),
        'difficulty_preference': difficultyFeedback['too_hard']! > difficultyFeedback['too_easy']!
            ? 'prefer_easier'
            : difficultyFeedback['too_easy']! > difficultyFeedback['too_hard']!
                ? 'prefer_harder'
                : 'balanced',
        'total_feedbacks': feedbacks.length,
      };
    } catch (e, st) {
      debugPrint('获取用户偏好摘要失败: $e');
      throw UserFeedbackRepositoryException('获取用户偏好摘要失败', e, st);
    }
  }

  /// 检查某个项目是否曾被用户反馈过
  Future<bool> hasFeedbackForItem({
    required String itemName,
    FeedbackType? type,
    int? userProfileId,
  }) async {
    try {
      final query = _db.select(_db.userFeedbacks)
        ..where((f) => f.originalName.equals(itemName));

      if (type != null) {
        query.where((f) => f.feedbackType.equals(type.value));
      }
      if (userProfileId != null) {
        query.where((f) => f.userProfileId.equals(userProfileId));
      }

      return await query.get().then((list) => list.isNotEmpty);
    } catch (e, st) {
      debugPrint('检查项目反馈失败: $e');
      throw UserFeedbackRepositoryException('检查项目反馈失败', e, st);
    }
  }
}

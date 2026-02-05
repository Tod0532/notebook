/// 用户画像仓库 - 封装用户画像相关的数据库操作
/// 包含统一的异常处理

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

/// 用户画像仓库异常类
class UserProfileRepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  UserProfileRepositoryException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'UserProfileRepositoryException: $message';
  }
}

class UserProfileRepository {
  final AppDatabase _db;

  UserProfileRepository(this._db);

  /// 获取最新的用户画像
  Future<UserProfile?> getLatestProfile() async {
    try {
      final profiles = await (_db.select(_db.userProfiles)
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)])
            ..limit(1))
          .get();
      return profiles.firstOrNull;
    } catch (e, st) {
      debugPrint('获取最新用户画像失败: $e');
      throw UserProfileRepositoryException('获取最新用户画像失败', e, st);
    }
  }

  /// 根据ID获取用户画像
  Future<UserProfile?> getProfileById(int id) async {
    try {
      return await (_db.select(_db.userProfiles)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    } catch (e, st) {
      debugPrint('获取用户画像详情失败: $e');
      throw UserProfileRepositoryException('获取用户画像详情失败', e, st);
    }
  }

  /// 创建用户画像
  Future<int> createProfile(UserProfilesCompanion profile) async {
    try {
      return await _db.into(_db.userProfiles).insert(profile);
    } catch (e, st) {
      debugPrint('创建用户画像失败: $e');
      throw UserProfileRepositoryException('创建用户画像失败', e, st);
    }
  }

  /// 更新用户画像
  Future<bool> updateProfile(UserProfile profile) async {
    try {
      return await _db.update(_db.userProfiles).replace(profile);
    } catch (e, st) {
      debugPrint('更新用户画像失败: $e');
      throw UserProfileRepositoryException('更新用户画像失败', e, st);
    }
  }

  /// 更新用户画像部分字段
  Future<void> updateProfileFields(int id, UserProfilesCompanion companion) async {
    try {
      await (_db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(id))).write(companion);
    } catch (e, st) {
      debugPrint('更新用户画像字段失败: $e');
      throw UserProfileRepositoryException('更新用户画像字段失败', e, st);
    }
  }

  /// 删除用户画像
  Future<int> deleteProfile(int id) async {
    try {
      return await (_db.delete(_db.userProfiles)..where((tbl) => tbl.id.equals(id))).go();
    } catch (e, st) {
      debugPrint('删除用户画像失败: $e');
      throw UserProfileRepositoryException('删除用户画像失败', e, st);
    }
  }

  /// 获取所有用户画像历史
  Future<List<UserProfile>> getAllProfiles() async {
    try {
      return await (_db.select(_db.userProfiles)
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取所有用户画像失败: $e');
      throw UserProfileRepositoryException('获取所有用户画像失败', e, st);
    }
  }

  /// 解析JSON数组字符串
  static List<String> parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]') return [];
    try {
      final decoded = jsonDecode(jsonStr) as List;
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('解析JSON数组失败: $e');
      return [];
    }
  }

  /// 格式化为JSON数组字符串
  static String formatJsonList(List<String> list) {
    if (list.isEmpty) return '[]';
    return jsonEncode(list);
  }
}

/// 用户画像仓库 - 封装用户画像相关的数据库操作

import 'dart:convert';
import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

class UserProfileRepository {
  final AppDatabase _db;

  UserProfileRepository(this._db);

  /// 获取最新的用户画像
  Future<UserProfile?> getLatestProfile() async {
    final profiles = await (_db.select(_db.userProfiles)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)])
          ..limit(1))
        .get();
    return profiles.firstOrNull;
  }

  /// 根据ID获取用户画像
  Future<UserProfile?> getProfileById(int id) async {
    return await (_db.select(_db.userProfiles)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建用户画像
  Future<int> createProfile(UserProfilesCompanion profile) async {
    return await _db.into(_db.userProfiles).insert(profile);
  }

  /// 更新用户画像
  Future<bool> updateProfile(UserProfile profile) async {
    return await _db.update(_db.userProfiles).replace(profile);
  }

  /// 更新用户画像部分字段
  Future<void> updateProfileFields(int id, UserProfilesCompanion companion) async {
    await (_db.update(_db.userProfiles)..where((tbl) => tbl.id.equals(id))).write(companion);
  }

  /// 删除用户画像
  Future<int> deleteProfile(int id) async {
    return await (_db.delete(_db.userProfiles)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 获取所有用户画像历史
  Future<List<UserProfile>> getAllProfiles() async {
    return await (_db.select(_db.userProfiles)
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 解析JSON数组字符串
  static List<String> parseJsonList(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty || jsonStr == '[]') return [];
    try {
      final decoded = jsonDecode(jsonStr) as List;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  /// 格式化为JSON数组字符串
  static String formatJsonList(List<String> list) {
    if (list.isEmpty) return '[]';
    return jsonEncode(list);
  }
}

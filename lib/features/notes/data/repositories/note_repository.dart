/// 笔记仓库 - 封装笔记相关的数据库操作
/// 包含统一的异常处理

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/services/challenge/challenge_service.dart';
import 'package:drift/drift.dart' as drift;

/// 笔记仓库异常类
class NoteRepositoryException implements Exception {
  final String message;
  final dynamic originalError;
  final StackTrace? stackTrace;

  NoteRepositoryException(
    this.message, [
    this.originalError,
    this.stackTrace,
  ]);

  @override
  String toString() {
    return 'NoteRepositoryException: $message';
  }
}

class NoteRepository {
  final AppDatabase _db;
  ChallengeService? _challengeService;

  NoteRepository(this._db);

  /// 设置挑战服务（可选，用于挑战进度更新）
  void setChallengeService(ChallengeService? service) {
    _challengeService = service;
  }

  /// 获取所有笔记（未删除）
  Future<List<Note>> getAllNotes() async {
    try {
      return await (_db.select(_db.notes)
            ..where((tbl) => tbl.isDeleted.equals(false))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取笔记列表失败: $e');
      throw NoteRepositoryException('获取笔记列表失败', e, st);
    }
  }

  /// 获取已删除的笔记（回收站）
  Future<List<Note>> getDeletedNotes() async {
    try {
      return await (_db.select(_db.notes)
            ..where((tbl) => tbl.isDeleted.equals(true))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.deletedAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取已删除笔记失败: $e');
      throw NoteRepositoryException('获取已删除笔记失败', e, st);
    }
  }

  /// 按文件夹筛选笔记
  Future<List<Note>> getNotesByFolder(String folder) async {
    try {
      return await (_db.select(_db.notes)
            ..where((tbl) => tbl.isDeleted.equals(false) & tbl.folder.equals(folder))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('按文件夹获取笔记失败: $e');
      throw NoteRepositoryException('按文件夹获取笔记失败', e, st);
    }
  }

  /// 获取所有文件夹列表
  Future<List<String>> getAllFolders() async {
    try {
      final notes = await getAllNotes();
      final folders = notes
          .map((n) => n.folder)
          .where((f) => f != null && f.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      folders.sort();
      return folders;
    } catch (e, st) {
      debugPrint('获取文件夹列表失败: $e');
      throw NoteRepositoryException('获取文件夹列表失败', e, st);
    }
  }

  /// 按标签筛选笔记
  Future<List<Note>> getNotesByTag(String tag) async {
    try {
      final allNotes = await getAllNotes();
      return allNotes.where((note) {
        final tags = _parseTags(note.tags);
        return tags.contains(tag);
      }).toList();
    } catch (e, st) {
      debugPrint('按标签获取笔记失败: $e');
      throw NoteRepositoryException('按标签获取笔记失败', e, st);
    }
  }

  /// 获取置顶笔记
  Future<List<Note>> getPinnedNotes() async {
    try {
      return await (_db.select(_db.notes)
            ..where((tbl) => tbl.isPinned.equals(true) & tbl.isDeleted.equals(false))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
          .get();
    } catch (e, st) {
      debugPrint('获取置顶笔记失败: $e');
      throw NoteRepositoryException('获取置顶笔记失败', e, st);
    }
  }

  /// 搜索笔记
  Future<List<Note>> searchNotes(String keyword) async {
    try {
      final allNotes = await getAllNotes();
      final lowerKeyword = keyword.toLowerCase();
      return allNotes.where((note) {
        return (note.title?.toLowerCase().contains(lowerKeyword) ?? false) ||
            note.content.toLowerCase().contains(lowerKeyword);
      }).toList();
    } catch (e, st) {
      debugPrint('搜索笔记失败: $e');
      throw NoteRepositoryException('搜索笔记失败', e, st);
    }
  }

  /// 获取单个笔记
  Future<Note?> getNoteById(int id) async {
    try {
      return await (_db.select(_db.notes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    } catch (e, st) {
      debugPrint('获取笔记详情失败: $e');
      throw NoteRepositoryException('获取笔记详情失败', e, st);
    }
  }

  /// 创建笔记
  Future<int> createNote(NotesCompanion note) async {
    try {
      final id = await _db.into(_db.notes).insert(note);

      // 更新挑战进度（异步，不影响主流程）
      if (_challengeService != null) {
        _challengeService!.onNoteCreated().catchError(
          (e, s) => debugPrint('更新笔记挑战进度失败: $e\n$s'),
        );
      }

      return id;
    } catch (e, st) {
      debugPrint('创建笔记失败: $e');
      throw NoteRepositoryException('创建笔记失败', e, st);
    }
  }

  /// 更新笔记
  Future<bool> updateNote(Note note) async {
    try {
      return await _db.update(_db.notes).replace(note);
    } catch (e, st) {
      debugPrint('更新笔记失败: $e');
      throw NoteRepositoryException('更新笔记失败', e, st);
    }
  }

  /// 删除笔记（软删除）
  Future<int> deleteNote(int id) async {
    try {
      return await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(id)))
          .write(NotesCompanion(
            isDeleted: const drift.Value(true),
            deletedAt: drift.Value(DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ));
    } catch (e, st) {
      debugPrint('删除笔记失败: $e');
      throw NoteRepositoryException('删除笔记失败', e, st);
    }
  }

  /// 恢复笔记（从回收站恢复）
  Future<int> restoreNote(int id) async {
    try {
      return await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(id)))
          .write(NotesCompanion(
            isDeleted: const drift.Value(false),
            deletedAt: const drift.Value(null),
            updatedAt: drift.Value(DateTime.now()),
          ));
    } catch (e, st) {
      debugPrint('恢复笔记失败: $e');
      throw NoteRepositoryException('恢复笔记失败', e, st);
    }
  }

  /// 永久删除
  Future<int> permanentlyDeleteNote(int id) async {
    try {
      return await (_db.delete(_db.notes)..where((tbl) => tbl.id.equals(id))).go();
    } catch (e, st) {
      debugPrint('永久删除笔记失败: $e');
      throw NoteRepositoryException('永久删除笔记失败', e, st);
    }
  }

  /// 切换置顶状态
  Future<void> togglePin(Note note) async {
    try {
      await updateNote(note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()));
    } catch (e, st) {
      debugPrint('切换置顶状态失败: $e');
      throw NoteRepositoryException('切换置顶状态失败', e, st);
    }
  }

  /// 获取所有标签
  Future<List<String>> getAllTags() async {
    try {
      final notes = await getAllNotes();
      final tagSet = <String>{};
      for (final note in notes) {
        tagSet.addAll(_parseTags(note.tags));
      }
      return tagSet.toList()..sort();
    } catch (e, st) {
      debugPrint('获取标签列表失败: $e');
      throw NoteRepositoryException('获取标签列表失败', e, st);
    }
  }

  /// 解析标签JSON
  List<String> _parseTags(String tagsJson) {
    if (tagsJson.isEmpty || tagsJson == '[]') return [];
    try {
      final List<dynamic> jsonList = jsonDecode(tagsJson);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('解析标签JSON失败: $e');
      return [];
    }
  }

  /// 格式化标签为JSON字符串
  String formatTags(List<String> tags) {
    if (tags.isEmpty) return '[]';
    return '[${tags.map((e) => '"$e"').join(',')}]';
  }

  /// 解析图片JSON字符串
  List<String> _parseImages(String? imagesJson) {
    if (imagesJson == null || imagesJson.isEmpty || imagesJson == '[]') return [];
    try {
      final List<dynamic> jsonList = jsonDecode(imagesJson);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('解析图片JSON失败: $e');
      return [];
    }
  }

  /// 格式化图片为JSON字符串
  String formatImages(List<String> images) {
    if (images.isEmpty) return '[]';
    return '[${images.map((e) => '"$e"').join(',')}]';
  }

  /// 获取所有笔记中使用的图片路径
  Future<List<String>> getAllUsedImagePaths() async {
    try {
      final notes = await getAllNotes();
      final allImages = <String>[];
      for (final note in notes) {
        allImages.addAll(_parseImages(note.images));
      }
      return allImages;
    } catch (e, st) {
      debugPrint('获取使用图片路径失败: $e');
      throw NoteRepositoryException('获取使用图片路径失败', e, st);
    }
  }

  /// 清理空笔记（标题和内容都为空的笔记）
  Future<int> cleanEmptyNotes() async {
    try {
      final allNotes = await (_db.select(_db.notes)).get();
      int deletedCount = 0;
      for (final note in allNotes) {
        final titleIsEmpty = note.title == null || note.title!.isEmpty;
        final contentIsEmpty = note.content.isEmpty;
        if (titleIsEmpty && contentIsEmpty) {
          await permanentlyDeleteNote(note.id);
          deletedCount++;
        }
      }
      return deletedCount;
    } catch (e, st) {
      debugPrint('清理空笔记失败: $e');
      throw NoteRepositoryException('清理空笔记失败', e, st);
    }
  }

  /// 删除所有笔记
  Future<void> deleteAllNotes() async {
    try {
      await _db.delete(_db.notes).go();
    } catch (e, st) {
      debugPrint('删除所有笔记失败: $e');
      throw NoteRepositoryException('删除所有笔记失败', e, st);
    }
  }

  /// 从 JSON 数据创建笔记（用于备份恢复）
  Future<int> createNoteFromData(Map<String, dynamic> data) async {
    try {
      final companion = NotesCompanion.insert(
        title: drift.Value(data['title'] as String?),
        content: data['content'] as String? ?? '',
        tags: drift.Value(data['tags'] as String? ?? '[]'),
        isPinned: data['is_pinned'] as bool? ?? false ? const drift.Value(true) : const drift.Value(false),
        createdAt: drift.Value(DateTime.parse(data['created_at'] as String)),
        updatedAt: drift.Value(DateTime.parse(data['updated_at'] as String)),
        isDeleted: data['is_deleted'] as bool? ?? false ? const drift.Value(true) : const drift.Value(false),
      );
      return await _db.into(_db.notes).insert(companion);
    } catch (e, st) {
      debugPrint('从数据创建笔记失败: $e');
      throw NoteRepositoryException('从数据创建笔记失败', e, st);
    }
  }
}

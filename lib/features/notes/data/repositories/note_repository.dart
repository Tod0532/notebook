/// 笔记仓库 - 封装笔记相关的数据库操作

import 'package:thick_notepad/services/database/database.dart';
import 'package:drift/drift.dart' as drift;

class NoteRepository {
  final AppDatabase _db;

  NoteRepository(this._db);

  /// 获取所有笔记（未删除）
  Future<List<Note>> getAllNotes() async {
    return await (_db.select(_db.notes)
          ..where((tbl) => tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 获取已删除的笔记（回收站）
  Future<List<Note>> getDeletedNotes() async {
    return await (_db.select(_db.notes)
          ..where((tbl) => tbl.isDeleted.equals(true))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.deletedAt)]))
        .get();
  }

  /// 按文件夹筛选笔记
  Future<List<Note>> getNotesByFolder(String folder) async {
    return await (_db.select(_db.notes)
          ..where((tbl) => tbl.isDeleted.equals(false) & tbl.folder.equals(folder))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 获取所有文件夹列表
  Future<List<String>> getAllFolders() async {
    final notes = await getAllNotes();
    final folders = notes
        .map((n) => n.folder)
        .where((f) => f != null && f.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    folders.sort();
    return folders;
  }

  /// 按标签筛选笔记
  Future<List<Note>> getNotesByTag(String tag) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) {
      final tags = _parseTags(note.tags);
      return tags.contains(tag);
    }).toList();
  }

  /// 获取置顶笔记
  Future<List<Note>> getPinnedNotes() async {
    return await (_db.select(_db.notes)
          ..where((tbl) => tbl.isPinned.equals(true) & tbl.isDeleted.equals(false))
          ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.createdAt)]))
        .get();
  }

  /// 搜索笔记
  Future<List<Note>> searchNotes(String keyword) async {
    final allNotes = await getAllNotes();
    final lowerKeyword = keyword.toLowerCase();
    return allNotes.where((note) {
      return (note.title?.toLowerCase().contains(lowerKeyword) ?? false) ||
          note.content.toLowerCase().contains(lowerKeyword);
    }).toList();
  }

  /// 获取单个笔记
  Future<Note?> getNoteById(int id) async {
    return await (_db.select(_db.notes)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  /// 创建笔记
  Future<int> createNote(NotesCompanion note) async {
    return await _db.into(_db.notes).insert(note);
  }

  /// 更新笔记
  Future<bool> updateNote(Note note) async {
    return await _db.update(_db.notes).replace(note);
  }

  /// 删除笔记（软删除）
  Future<int> deleteNote(int id) async {
    return await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(id)))
        .write(NotesCompanion(
          isDeleted: const drift.Value(true),
          deletedAt: drift.Value(DateTime.now()),
          updatedAt: drift.Value(DateTime.now()),
        ));
  }

  /// 恢复笔记（从回收站恢复）
  Future<int> restoreNote(int id) async {
    return await (_db.update(_db.notes)..where((tbl) => tbl.id.equals(id)))
        .write(NotesCompanion(
          isDeleted: const drift.Value(false),
          deletedAt: const drift.Value(null),
          updatedAt: drift.Value(DateTime.now()),
        ));
  }

  /// 永久删除
  Future<int> permanentlyDeleteNote(int id) async {
    return await (_db.delete(_db.notes)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// 切换置顶状态
  Future<void> togglePin(Note note) async {
    await updateNote(note.copyWith(isPinned: !note.isPinned, updatedAt: DateTime.now()));
  }

  /// 获取所有标签
  Future<List<String>> getAllTags() async {
    final notes = await getAllNotes();
    final tagSet = <String>{};
    for (final note in notes) {
      tagSet.addAll(_parseTags(note.tags));
    }
    return tagSet.toList()..sort();
  }

  /// 解析标签JSON
  List<String> _parseTags(String tagsJson) {
    if (tagsJson.isEmpty || tagsJson == '[]') return [];
    try {
      // 简单的JSON解析
      final content = tagsJson.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
      if (content.isEmpty) return [];
      return content.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
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
      final content = imagesJson.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '').replaceAll("'", '');
      if (content.isEmpty) return [];
      return content.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
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
    final notes = await getAllNotes();
    final allImages = <String>[];
    for (final note in notes) {
      allImages.addAll(_parseImages(note.images));
    }
    return allImages;
  }

  /// 清理空笔记（标题和内容都为空的笔记）
  Future<int> cleanEmptyNotes() async {
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
  }

  /// 删除所有笔记
  Future<void> deleteAllNotes() async {
    await _db.delete(_db.notes).go();
  }

  /// 从 JSON 数据创建笔记（用于备份恢复）
  Future<int> createNoteFromData(Map<String, dynamic> data) async {
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
  }
}

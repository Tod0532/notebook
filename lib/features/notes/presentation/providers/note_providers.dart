/// 笔记模块 Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';

// ==================== 笔记列表 Provider ====================

/// 所有笔记 Provider
final allNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getAllNotes();
});

/// 置顶笔记 Provider
final pinnedNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getPinnedNotes();
});

/// 按标签筛选的笔记 Provider 族
final notesByTagProvider = FutureProvider.autoDispose.family<List<Note>, String>((ref, tag) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getNotesByTag(tag);
});

/// 搜索笔记 Provider 族
final searchNotesProvider = FutureProvider.autoDispose.family<List<Note>, String>((ref, keyword) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.searchNotes(keyword);
});

/// 单个笔记 Provider 族
final noteProvider = FutureProvider.autoDispose.family<Note?, int>((ref, id) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getNoteById(id);
});

/// 所有标签 Provider
final allTagsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getAllTags();
});

/// 回收站笔记 Provider
final deletedNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getDeletedNotes();
});

/// 文件夹列表 Provider
final allFoldersProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getAllFolders();
});

/// 按文件夹筛选的笔记 Provider 族
final notesByFolderProvider = FutureProvider.autoDispose.family<List<Note>, String>((ref, folder) async {
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getNotesByFolder(folder);
});

// ==================== 笔记操作 Providers ====================

/// 创建笔记状态
class CreateNoteState extends StateNotifier<AsyncValue<int?>> {
  CreateNoteState(this.repository) : super(const AsyncValue.data(null));

  final NoteRepository repository;

  Future<int?> create(NotesCompanion note) async {
    state = const AsyncValue.loading();
    try {
      final id = await repository.createNote(note);
      state = AsyncValue.data(id);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final createNoteProvider = StateNotifierProvider<CreateNoteState, AsyncValue<void>>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return CreateNoteState(repository);
});

/// 更新笔记状态
class UpdateNoteState extends StateNotifier<AsyncValue<void>> {
  UpdateNoteState(this.repository) : super(const AsyncValue.data(null));

  final NoteRepository repository;

  Future<void> update(Note note) async {
    state = const AsyncValue.loading();
    try {
      await repository.updateNote(note);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> togglePin(Note note) async {
    state = const AsyncValue.loading();
    try {
      await repository.togglePin(note);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> delete(int id) async {
    state = const AsyncValue.loading();
    try {
      await repository.deleteNote(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> restore(int id) async {
    state = const AsyncValue.loading();
    try {
      await repository.restoreNote(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> permanentlyDelete(int id) async {
    state = const AsyncValue.loading();
    try {
      await repository.permanentlyDeleteNote(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final updateNoteProvider = StateNotifierProvider<UpdateNoteState, AsyncValue<void>>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  return UpdateNoteState(repository);
});

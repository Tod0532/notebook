/// 笔记模块 Providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/core/config/providers.dart';
import 'package:thick_notepad/services/database/database.dart';
import 'package:thick_notepad/features/notes/data/repositories/note_repository.dart';

// ==================== 笔记列表 Provider ====================

/// 分页笔记状态管理
class PagedNotesState extends StateNotifier<AsyncValue<PagedResult<Note>>> {
  PagedNotesState(this.repository) : super(const AsyncValue.loading()) {
    loadFirstPage();
  }

  final NoteRepository repository;
  PaginationParams? _currentParams;

  /// 加载第一页
  Future<void> loadFirstPage() async {
    _currentParams = const PaginationParams(page: 1, pageSize: 20);
    state = const AsyncValue.loading();
    await _loadPage();
  }

  /// 加载下一页
  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) return;

    _currentParams = current.nextPageParams();
    await _loadPage(append: true);
  }

  Future<void> _loadPage({bool append = false}) async {
    if (_currentParams == null) return;

    try {
      final result = await repository.getNotesPaged(_currentParams);

      if (append && state.valueOrNull != null) {
        // 追加模式：合并数据
        final existingItems = state.valueOrNull!.items;
        state = AsyncValue.data(result.copyWith(
          items: [...existingItems, ...result.items],
        ));
      } else {
        state = AsyncValue.data(result);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 刷新列表
  Future<void> refresh() async {
    await loadFirstPage();
  }
}

/// 所有笔记 Provider（使用 keepAlive 缓存）
final allNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  // 添加缓存失效监听器
  ref.onDispose(() {
    // 可以在这里清理资源
  });

  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getAllNotes();
});

/// 分页笔记 Provider（优化版 - 支持增量加载）
final pagedNotesProvider = StateNotifierProvider<PagedNotesState, AsyncValue<PagedResult<Note>>>((ref) {
  final repository = ref.watch(noteRepositoryProvider);
  ref.keepAlive(); // 保持状态不自动释放
  return PagedNotesState(repository);
});

/// 置顶笔记 Provider（添加缓存）
final pinnedNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  ref.keepAlive(); // 保持缓存
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getPinnedNotes();
});

/// 按标签筛选的笔记 Provider 族（添加缓存）
final notesByTagProvider = FutureProvider.autoDispose.family<List<Note>, String>((ref, tag) async {
  ref.keepAlive(); // 保持缓存
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getNotesByTag(tag);
});

/// 搜索笔记 Provider 族（添加缓存）
final searchNotesProvider = FutureProvider.autoDispose.family<List<Note>, String>((ref, keyword) async {
  ref.keepAlive(); // 保持缓存
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.searchNotes(keyword);
});

/// 单个笔记 Provider 族（添加缓存）
final noteProvider = FutureProvider.autoDispose.family<Note?, int>((ref, id) async {
  ref.keepAlive(); // 保持缓存
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getNoteById(id);
});

/// 所有标签 Provider（添加缓存）
final allTagsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  ref.keepAlive(); // 保持缓存
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getAllTags();
});

/// 回收站笔记 Provider（添加缓存）
final deletedNotesProvider = FutureProvider.autoDispose<List<Note>>((ref) async {
  ref.keepAlive(); // 保持缓存
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getDeletedNotes();
});

/// 文件夹列表 Provider（添加缓存）
final allFoldersProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  ref.keepAlive(); // 保持缓存
  final repository = ref.watch(noteRepositoryProvider);
  return await repository.getAllFolders();
});

/// 按文件夹筛选的笔记 Provider 族（添加缓存）
final notesByFolderProvider = FutureProvider.autoDispose.family<List<Note>, String>((ref, folder) async {
  ref.keepAlive(); // 保持缓存
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

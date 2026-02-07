/// 图片预览组件 - 支持滑动查看、删除、拖拽排序

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/core/utils/haptic_helper.dart';

/// 图片预览网格组件
class ImagePreviewGrid extends StatefulWidget {
  final List<String> imagePaths;
  final ValueChanged<List<String>> onImagesChanged;
  final int maxImages;
  final bool enableReorder;

  const ImagePreviewGrid({
    super.key,
    required this.imagePaths,
    required this.onImagesChanged,
    this.maxImages = 10,
    this.enableReorder = true,
  });

  @override
  State<ImagePreviewGrid> createState() => _ImagePreviewGridState();
}

class _ImagePreviewGridState extends State<ImagePreviewGrid> {
  late List<String> _images;
  int _longPressIndex = -1;

  @override
  void initState() {
    super.initState();
    _images = List.from(widget.imagePaths);
  }

  @override
  void didUpdateWidget(ImagePreviewGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 比较列表长度和内容，而不仅仅是引用
    if (oldWidget.imagePaths.length != widget.imagePaths.length ||
        !oldWidget.imagePaths.every((element) => widget.imagePaths.contains(element))) {
      setState(() {
        _images = List.from(widget.imagePaths);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 16,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 6),
              Text(
                '已添加 ${_images.length} 张图片',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textHint,
                    ),
              ),
              const Spacer(),
              if (_images.isNotEmpty)
                TextButton(
                  onPressed: _clearAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    '清空',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.error,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildImageGrid(),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    // 当禁用重排时使用普通ListView，否则使用ReorderableListView
    if (!widget.enableReorder) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _images.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          return _buildImageItem(index);
        },
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      proxyDecorator: _buildProxyDecorator,
      itemCount: _images.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        return _buildImageItem(index);
      },
    );
  }

  Widget _buildImageItem(int index) {
    final imagePath = _images[index];
    final file = File(imagePath);

    return Container(
      key: ValueKey(imagePath),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽手柄
          if (widget.enableReorder)
            Container(
              margin: const EdgeInsets.only(top: 40, right: 8),
              child: Icon(
                Icons.drag_handle,
                color: AppColors.textHint.withOpacity(0.5),
                size: 20,
              ),
            ),
          // 图片预览
          Expanded(
            child: InkWell(
              onTap: () => _previewImage(index),
              onLongPress: () {
                HapticHelper.mediumTap();
                _showImageOptions(context, index);
              },
              borderRadius: AppRadius.mdRadius,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.mdRadius,
                  border: Border.all(
                    color: AppColors.dividerColor.withOpacity(0.3),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: AppRadius.mdRadius,
                  child: Stack(
                    children: [
                      // 图片 - 优化缓存和加载
                      Positioned.fill(
                        child: _OptimizedImage(
                          file: file,
                          errorWidget: _buildErrorPlaceholder(),
                        ),
                      ),
                      // 序号
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      // 删除按钮
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () {
                            HapticHelper.lightTap();
                            _removeImage(index);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 32,
              color: AppColors.textHint.withOpacity(0.5),
            ),
            const SizedBox(height: 4),
            Text(
              '图片加载失败',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final animValue = Curves.easeInOut.transform(animation.value);
        return Opacity(
          opacity: 0.9,
          child: Transform.scale(
            scale: 1.0 + (0.05 * animValue),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    HapticHelper.lightTap();
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _images.removeAt(oldIndex);
      _images.insert(newIndex, item);
    });
    widget.onImagesChanged(_images);
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
    widget.onImagesChanged(_images);
  }

  void _clearAll() {
    HapticHelper.lightTap();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有图片'),
        content: const Text('确定要清空所有图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _images.clear();
              });
              widget.onImagesChanged(_images);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _previewImage(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ImagePreviewPage(
          imagePaths: _images,
          initialIndex: index,
        ),
      ),
    );
  }

  void _showImageOptions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('查看图片'),
                onTap: () {
                  Navigator.pop(context);
                  _previewImage(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('删除图片', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 图片预览页面 - 支持滑动切换
class _ImagePreviewPage extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const _ImagePreviewPage({
    required this.imagePaths,
    required this.initialIndex,
  });

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imagePaths.length}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 图片查看器
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.imagePaths.length,
            itemBuilder: (context, index) {
              final imagePath = widget.imagePaths[index];
              final file = File(imagePath);

              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: file.existsSync()
                      ? Image.file(
                          file,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '图片加载失败',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                size: 64,
                                color: Colors.white54,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '图片不存在',
                                style: TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              );
            },
          ),
          // 左右指示器
          if (widget.imagePaths.length > 1) ...[
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildNavigationButton(
                  icon: Icons.chevron_left,
                  onTap: _currentIndex > 0
                      ? () {
                          HapticHelper.lightTap();
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: _buildNavigationButton(
                  icon: Icons.chevron_right,
                  onTap: _currentIndex < widget.imagePaths.length - 1
                      ? () {
                          HapticHelper.lightTap();
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;
    return Container(
      decoration: BoxDecoration(
        color: isEnabled
            ? Colors.white.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 32),
        onPressed: onTap,
      ),
    );
  }
}

/// 内存缓存 - LRU策略限制内存占用
class _ImageMemoryCache {
  static final Map<String, Uint8List> _cache = {};
  static final List<String> _lruKeys = [];
  static const int _maxCacheSize = 10; // 最多缓存10张图片
  static const int _maxCacheBytes = 10 * 1024 * 1024; // 最多10MB

  static int _currentBytes = 0;

  static Uint8List? get(String path) {
    if (_cache.containsKey(path)) {
      // 更新LRU顺序
      _lruKeys.remove(path);
      _lruKeys.add(path);
      return _cache[path];
    }
    return null;
  }

  static void put(String path, Uint8List bytes) {
    // 移除旧值
    if (_cache.containsKey(path)) {
      _currentBytes -= _cache[path]!.length;
      _lruKeys.remove(path);
      _cache.remove(path);
    }

    // 淘汰策略
    while (_lruKeys.length >= _maxCacheSize || _currentBytes + bytes.length > _maxCacheBytes) {
      if (_lruKeys.isEmpty) break;
      final oldestKey = _lruKeys.removeAt(0);
      final oldestBytes = _cache.remove(oldestKey);
      if (oldestBytes != null) _currentBytes -= oldestBytes.length;
    }

    _cache[path] = bytes;
    _lruKeys.add(path);
    _currentBytes += bytes.length;
  }

  static void clear() {
    _cache.clear();
    _lruKeys.clear();
    _currentBytes = 0;
  }
}

/// 优化的图片组件 - 带缓存和渐进式加载
class _OptimizedImage extends StatefulWidget {
  final File file;
  final Widget errorWidget;

  const _OptimizedImage({
    required this.file,
    required this.errorWidget,
  });

  @override
  State<_OptimizedImage> createState() => _OptimizedImageState();
}

class _OptimizedImageState extends State<_OptimizedImage> {
  Uint8List? _imageData;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final path = widget.file.path;

    // 先检查内存缓存
    final cached = _ImageMemoryCache.get(path);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _imageData = cached;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (!widget.file.existsSync()) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        }
        return;
      }

      final bytes = await widget.file.readAsBytes();

      // 存入缓存
      _ImageMemoryCache.put(path, bytes);

      if (mounted) {
        setState(() {
          _imageData = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(_OptimizedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      setState(() {
        _imageData = null;
        _isLoading = true;
        _hasError = false;
      });
      _loadImage();
    }
  }

  @override
  void dispose() {
    // 不在这里清理内存，让缓存管理器统一处理
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.errorWidget;
    }

    if (_isLoading || _imageData == null) {
      return Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Image.memory(
      _imageData!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return widget.errorWidget;
      },
    );
  }
}

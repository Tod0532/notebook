/// 图片预览组件 - 支持滑动查看、删除、拖拽排序

import 'dart:io';
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
    if (oldWidget.imagePaths != widget.imagePaths) {
      _images = List.from(widget.imagePaths);
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
                      // 图片
                      Positioned.fill(
                        child: file.existsSync()
                            ? Image.file(
                                file,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildErrorPlaceholder();
                                },
                              )
                            : _buildErrorPlaceholder(),
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

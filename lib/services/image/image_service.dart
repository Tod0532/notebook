/// 图片服务 - 处理图片压缩、保存和管理

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:permission_handler/permission_handler.dart';

/// 图片配置
class ImageConfig {
  /// 最大压缩宽度
  static const int maxImageWidth = 1080;

  /// 图片压缩质量 (0-100)
  static const int imageQuality = 85;

  /// 最大图片数量
  static const int maxImagesPerNote = 10;

  /// 支持的图片格式
  static const List<String> supportedFormats = ['.jpg', '.jpeg', '.png', '.webp'];
}

/// 图片处理结果
class ImageResult {
  final String originalPath;
  final String? compressedPath;
  final int originalSize;
  final int? compressedSize;
  final String? error;

  ImageResult({
    required this.originalPath,
    this.compressedPath,
    required this.originalSize,
    this.compressedSize,
    this.error,
  });

  /// 压缩率
  double get compressionRatio {
    if (compressedSize == null || originalSize == 0) return 0;
    return (1 - compressedSize! / originalSize) * 100;
  }

  /// 是否成功
  bool get isSuccess => error == null;
}

/// 图片服务
class ImageService {
  static ImageService? _instance;
  final ImagePicker _picker = ImagePicker();

  ImageService._();

  /// 获取单例实例
  static ImageService get instance {
    _instance ??= ImageService._();
    return _instance!;
  }

  /// 获取应用图片存储目录
  Future<Directory> getImageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final imageDir = Directory(p.join(appDir.path, 'note_images'));

    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }

    return imageDir;
  }

  /// 检查和请求相册权限
  Future<bool> requestPhotoPermission() async {
    // Web 平台不需要相册权限
    if (kIsWeb) return true;

    // iOS 需要相册权限
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  /// 检查和请求相机权限
  Future<bool> requestCameraPermission() async {
    if (kIsWeb) return true;

    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// 选择多张图片
  Future<List<String>> pickMultiImage() async {
    try {
      final hasPermission = await requestPhotoPermission();
      if (!hasPermission) {
        debugPrint('没有相册权限');
        return [];
      }

      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: ImageConfig.imageQuality,
        limit: ImageConfig.maxImagesPerNote,
      );

      if (images.isEmpty) return [];

      // 并行处理图片压缩和保存
      final results = await Future.wait(
        images.map((img) => processAndSaveImage(img)),
      );

      // 只返回成功的图片路径
      return results
          .where((r) => r.isSuccess && r.compressedPath != null)
          .map((r) => r.compressedPath!)
          .toList();
    } catch (e) {
      debugPrint('选择图片失败: $e');
      return [];
    }
  }

  /// 拍照
  Future<String?> takePhoto() async {
    try {
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        debugPrint('没有相机权限');
        return null;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: ImageConfig.imageQuality,
      );

      if (photo == null) return null;

      final result = await processAndSaveImage(photo);
      return result.compressedPath;
    } catch (e) {
      debugPrint('拍照失败: $e');
      return null;
    }
  }

  /// 处理并保存图片（压缩）
  Future<ImageResult> processAndSaveImage(XFile imageFile) async {
    try {
      // 获取原始文件大小（通过 File）
      final originalFile = File(imageFile.path);
      final originalSize = await originalFile.length();
      final originalPath = imageFile.path;

      // 获取图片目录
      final imageDir = await getImageDirectory();

      // 生成唯一文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final randomSuffix = (timestamp % 10000).toString().padLeft(4, '0');
      final extension = p.extension(imageFile.path).toLowerCase();
      final fileName = 'img_$timestamp$randomSuffix$extension';
      final outputPath = p.join(imageDir.path, fileName);

      // 压缩图片
      final compressedXFile = await compressImage(
        originalFile,
        outputPath,
        maxWidth: ImageConfig.maxImageWidth,
        quality: ImageConfig.imageQuality,
      );

      if (compressedXFile == null) {
        return ImageResult(
          originalPath: originalPath,
          originalSize: originalSize,
          error: '压缩失败',
        );
      }

      // 获取压缩后文件大小
      final compressedFile = File(compressedXFile.path);
      final compressedSize = await compressedFile.length();

      debugPrint('图片压缩: 原始 ${(originalSize / 1024).toStringAsFixed(1)}KB -> '
          '压缩后 ${(compressedSize / 1024).toStringAsFixed(1)}KB '
          '(${((1 - compressedSize / originalSize) * 100).toStringAsFixed(0)}%)');

      return ImageResult(
        originalPath: originalPath,
        compressedPath: compressedXFile.path,
        originalSize: originalSize,
        compressedSize: compressedSize,
      );
    } catch (e) {
      debugPrint('处理图片失败: $e');
      return ImageResult(
        originalPath: imageFile.path,
        originalSize: 0,
        error: e.toString(),
      );
    }
  }

  /// 压缩图片
  Future<XFile?> compressImage(
    File sourceFile,
    String targetPath, {
    int maxWidth = ImageConfig.maxImageWidth,
    int quality = ImageConfig.imageQuality,
  }) async {
    try {
      // 保存压缩后的图片
      final result = await FlutterImageCompress.compressAndGetFile(
        sourceFile.path,
        targetPath,
        quality: quality,
        minWidth: 1,
        minHeight: 1,
        format: CompressFormat.jpeg,
      );

      return result;
    } catch (e) {
      debugPrint('压缩图片异常: $e');
      // 压缩失败时，尝试直接复制
      try {
        if (await sourceFile.exists()) {
          final copiedFile = await sourceFile.copy(targetPath);
          return XFile(copiedFile.path);
        }
      } catch (_) {}
      return null;
    }
  }

  /// 获取图片信息
  Future<Map<String, dynamic>> getImageInfo(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return {'exists': false};
      }

      final stat = await file.stat();
      final size = stat.size;
      final modified = stat.modified;

      return {
        'exists': true,
        'path': imagePath,
        'size': size,
        'sizeKB': (size / 1024).toStringAsFixed(1),
        'modified': modified,
      };
    } catch (e) {
      debugPrint('获取图片信息失败: $e');
      return {'exists': false, 'error': e.toString()};
    }
  }

  /// 删除图片
  Future<bool> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('已删除图片: $imagePath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('删除图片失败: $e');
      return false;
    }
  }

  /// 批量删除图片
  Future<int> deleteImages(List<String> imagePaths) async {
    int deletedCount = 0;
    for (final path in imagePaths) {
      if (await deleteImage(path)) {
        deletedCount++;
      }
    }
    return deletedCount;
  }

  /// 清理未使用的图片
  Future<int> cleanupUnusedImages(List<String> usedPaths) async {
    try {
      final imageDir = await getImageDirectory();
      if (!await imageDir.exists()) return 0;

      final usedSet = usedPaths.toSet();
      int deletedCount = 0;

      await for (final entity in imageDir.list()) {
        if (entity is File) {
          if (!usedSet.contains(entity.path)) {
            try {
              await entity.delete();
              deletedCount++;
            } catch (e) {
              debugPrint('删除未使用图片失败: ${entity.path}, $e');
            }
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint('清理了 $deletedCount 张未使用的图片');
      }

      return deletedCount;
    } catch (e) {
      debugPrint('清理未使用图片失败: $e');
      return 0;
    }
  }

  /// 获取存储空间使用情况
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final imageDir = await getImageDirectory();
      if (!await imageDir.exists()) {
        return {'totalSize': 0, 'fileCount': 0};
      }

      int totalSize = 0;
      int fileCount = 0;

      await for (final entity in imageDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
          fileCount++;
        }
      }

      return {
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
        'fileCount': fileCount,
      };
    } catch (e) {
      debugPrint('获取存储信息失败: $e');
      return {'totalSize': 0, 'fileCount': 0, 'error': e.toString()};
    }
  }

  /// 验证图片路径是否有效
  Future<bool> isImagePathValid(String imagePath) async {
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// 批量验证图片路径
  Future<List<String>> validateImagePaths(List<String> imagePaths) async {
    final validPaths = <String>[];
    for (final path in imagePaths) {
      if (await isImagePathValid(path)) {
        validPaths.add(path);
      }
    }
    return validPaths;
  }
}

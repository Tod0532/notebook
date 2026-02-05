/// 图片工具类 - 处理图片 JSON 序列化/反序列化

import 'dart:convert';

/// 图片工具类
class ImageUtils {
  /// 解析图片 JSON 字符串
  static List<String> parseImages(String? imagesJson) {
    if (imagesJson == null || imagesJson.isEmpty || imagesJson == '[]') {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(imagesJson);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      // 兼容旧格式：逗号分隔的字符串
      if (imagesJson.contains(',')) {
        return imagesJson.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }
  }

  /// 格式化图片为 JSON 字符串
  static String formatImages(List<String> images) {
    if (images.isEmpty) return '[]';
    final jsonEncoder = JsonEncoder();
    return jsonEncoder.convert(images);
  }

  /// 验证图片路径列表
  static List<String> filterValidPaths(List<String> paths) {
    return paths.where((path) => path.isNotEmpty).toList();
  }

  /// 合并图片路径列表（去重）
  static List<String> mergeImagePaths(List<String> existing, List<String> newImages) {
    final merged = [...existing, ...newImages];
    final unique = merged.toSet().toList();
    return unique;
  }

  /// 获取图片数量
  static int getImageCount(String? imagesJson) {
    return parseImages(imagesJson).length;
  }

  /// 是否有图片
  static bool hasImages(String? imagesJson) {
    return getImageCount(imagesJson) > 0;
  }

  /// 获取第一张图片路径
  static String? getFirstImage(String? imagesJson) {
    final images = parseImages(imagesJson);
    return images.isNotEmpty ? images.first : null;
  }
}

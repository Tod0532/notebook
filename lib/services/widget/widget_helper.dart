import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 桌面小组件辅助服务
/// 用于Flutter端与原生Android小组件通信
class WidgetHelper {
  static const MethodChannel _channel = MethodChannel('com.thicknotepad.thick_notepad/widget');

  /// 初始化MethodChannel
  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// 处理来自原生端的调用
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'getNoteData':
        // 返回笔记数据给小组件
        return await _getNoteData();
      case 'getPlanData':
        // 返回计划数据给小组件
        return await _getPlanData();
      case 'getWorkoutData':
        // 返回运动数据给小组件
        return await _getWorkoutData();
      default:
        throw UnimplementedError('${call.method} 未实现');
    }
  }

  /// 更新笔记小组件
  ///
  /// [noteCount] 笔记总数
  /// [recentNote] 最近笔记内容预览
  static Future<void> updateNoteWidget({
    required int noteCount,
    required String recentNote,
  }) async {
    try {
      await _channel.invokeMethod('updateNoteWidget', {
        'noteCount': noteCount,
        'recentNote': recentNote,
      });
    } catch (e) {
      debugPrint('更新笔记小组件失败: $e');
    }
  }

  /// 更新计划小组件
  ///
  /// [totalTasks] 总任务数
  /// [completedTasks] 已完成任务数
  static Future<void> updatePlanWidget({
    required int totalTasks,
    required int completedTasks,
  }) async {
    try {
      await _channel.invokeMethod('updatePlanWidget', {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
      });
    } catch (e) {
      debugPrint('更新计划小组件失败: $e');
    }
  }

  /// 更新运动打卡小组件
  ///
  /// [calories] 今日卡路里消耗
  /// [duration] 今日运动时长（分钟）
  /// [workoutType] 运动类型
  static Future<void> updateWorkoutWidget({
    required int calories,
    required int duration,
    String workoutType = '运动',
  }) async {
    try {
      await _channel.invokeMethod('updateWorkoutWidget', {
        'calories': calories,
        'duration': duration,
        'workoutType': workoutType,
      });
    } catch (e) {
      debugPrint('更新运动小组件失败: $e');
    }
  }

  /// 重置每日运动打卡状态
  static Future<void> resetWorkoutCheckin() async {
    try {
      await _channel.invokeMethod('resetWorkoutCheckin');
    } catch (e) {
      debugPrint('重置运动打卡失败: $e');
    }
  }

  /// 更新语音识别结果
  ///
  /// [result] 识别到的文本
  static Future<void> updateVoiceResult(String result) async {
    try {
      await _channel.invokeMethod('updateVoiceResult', {
        'result': result,
      });
    } catch (e) {
      debugPrint('更新语音结果失败: $e');
    }
  }

  /// 获取笔记数据（供原生调用）
  static Future<Map<String, dynamic>> _getNoteData() async {
    // TODO: 从实际数据源获取
    return {
      'noteCount': 0,
      'recentNote': '',
    };
  }

  /// 获取计划数据（供原生调用）
  static Future<Map<String, dynamic>> _getPlanData() async {
    // TODO: 从实际数据源获取
    return {
      'totalTasks': 0,
      'completedTasks': 0,
    };
  }

  /// 获取运动数据（供原生调用）
  static Future<Map<String, dynamic>> _getWorkoutData() async {
    // TODO: 从实际数据源获取
    return {
      'calories': 0,
      'duration': 0,
      'workoutType': '运动',
    };
  }
}

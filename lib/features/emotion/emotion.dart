/// 情绪分析模块导出文件
///
/// 提供情绪分析、运动推荐和趋势追踪功能

// ==================== 服务层 ====================
export 'package:thick_notepad/services/emotion/emotion_analyzer.dart';
export 'package:thick_notepad/services/emotion/emotion_workout_mapper.dart';

// ==================== 数据层 ====================
export 'package:thick_notepad/features/emotion/data/repositories/emotion_repository.dart';

// ==================== 展示层 - Providers ====================
export 'package:thick_notepad/features/emotion/presentation/providers/emotion_providers.dart';

// ==================== 展示层 - Widgets ====================
export 'package:thick_notepad/features/emotion/presentation/widgets/emotion_insight_card.dart';

// ==================== 展示层 - Pages ====================
export 'package:thick_notepad/features/emotion/presentation/pages/emotion_trend_page.dart';

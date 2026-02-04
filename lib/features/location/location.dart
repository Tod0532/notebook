/// 位置提醒功能模块导出
///
/// 此模块提供地理围栏和位置提醒功能，包括：
/// - 地理围栏的创建、编辑、删除
/// - 位置变化监控
/// - 到达/离开围栏时触发提醒
/// - 后台位置配置

// 数据仓库
export 'data/repositories/geofence_repository.dart';

// 展示层 Providers
export 'presentation/providers/location_providers.dart';

// 展示层页面
export 'presentation/pages/geofences_page.dart';
export 'presentation/pages/location_settings_page.dart';

// 展示层组件
export 'presentation/widgets/geofence_card.dart';
export 'presentation/widgets/geofence_map_editor.dart';

// 服务
export 'package:thick_notepad/services/location/geofence_service.dart';
export 'package:thick_notepad/services/location/background_location_service.dart';

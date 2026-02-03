# GPS 追踪功能实现总结

## 功能概述

实现了完整的运动GPS追踪功能，支持实时轨迹记录、距离计算、速度统计等功能。

## 已创建/修改的文件

### 1. 新增文件

#### `lib/services/gps/gps_tracking_service.dart`
- GPS追踪服务核心实现
- 单例模式，全局共享
- 功能点：
  - 位置权限检查和请求
  - 实时位置监听和轨迹记录
  - 距离计算（Haversine公式）
  - 速度、配速统计
  - 海拔变化统计
  - 后台位置追踪支持

#### `lib/features/workout/presentation/pages/gps_tracking_page.dart`
- GPS追踪UI页面
- 功能点：
  - 实时轨迹可视化（CustomPaint绘制）
  - 统计数据展示（距离、时长、速度、配速）
  - 开始/暂停/继续/结束控制
  - GPS状态指示器
  - 保存确认对话框

### 2. 修改的文件

#### `pubspec.yaml`
- 新增依赖：
  ```yaml
  geolocator: ^12.0.0      # GPS定位
  flutter_map: ^7.0.2      # 地图显示
  latlong2: ^0.9.1         # 经纬度处理
  ```

#### `android/app/src/main/AndroidManifest.xml`
- 新增权限：
  ```xml
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
  <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
  ```

#### `lib/core/config/router.dart`
- 新增路由：`/workout/gps`
- 支持参数：`?type=运动类型`

#### `lib/features/workout/presentation/pages/workout_edit_page.dart`
- 新增GPS追踪入口卡片（仅对有氧运动显示）
- GPS数据自动填充距离和时长

## 核心类说明

### GpsPoint
GPS位置点数据类，包含：
- 纬度、经度
- 时间戳
- 海拔、速度、精度

### GpsStatistics
GPS统计数据类，包含：
- 总距离
- 运动时长
- 平均速度、最大速度
- 平均配速
- 累计爬升/下降

### GpsTrackingService
GPS追踪服务，提供：
- `checkPermissions()` - 检查位置权限
- `startTracking()` - 开始追踪
- `pauseTracking()` - 暂停追踪
- `resumeTracking()` - 继续追踪
- `stopTracking()` - 停止追踪
- Stream订阅状态、轨迹、统计更新

### GpsTrackingStatus
追踪状态枚举：
- `idle` - 空闲
- `starting` - 启动中
- `tracking` - 追踪中
- `paused` - 已暂停
- `stopped` - 已停止

## 使用方法

### 1. 安装依赖
```bash
flutter pub get
```

### 2. 从运动编辑页启动GPS追踪
- 选择有氧运动类型（跑步、骑行等）
- 点击"记录运动轨迹"卡片
- 开始GPS追踪

### 3. 代码中使用
```dart
// 导航到GPS追踪页面
final result = await context.push<Map<String, dynamic>>(
  '/workout/gps?type=跑步',
);

// 获取追踪结果
if (result != null) {
  final distance = result['distance']; // 米
  final duration = result['duration']; // 秒
  final trackPoints = result['trackPoints']; // 轨迹点列表
}
```

## 数据库集成

运动记录表已支持距离字段（`distance`），GPS追踪的数据会自动保存：
```dart
WorkoutsCompanion.insert(
  // ...
  distance: drift.Value(_gpsDistance), // GPS记录的距离（米）
)
```

## 扩展建议

### 1. 真实地图集成
当前使用CustomPaint绘制简单轨迹，可替换为flutter_map显示OpenStreetMap：
```dart
FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(lat, lng),
    initialZoom: 15,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    PolylineLayer(
      polylines: [
        Polyline(
          points: trackPoints,
          strokeWidth: 4,
          color: AppColors.primary,
        ),
      ],
    ),
  ],
)
```

### 2. 屏幕常亮
使用 `wakelock_plus` 包保持屏幕常亮：
```yaml
dependencies:
  wakelock_plus: ^1.2.5
```

### 3. 后台通知
确保Android前台通知正确配置，已在`AndroidSettings`中设置。

### 4. 卡路里计算
根据运动类型、距离、体重计算消耗卡路里：
```dart
double _calculateCalories(String workoutType, double distanceKm, double weightKg) {
  final metMap = {
    'running': 9.8,
    'cycling': 7.5,
    'swimming': 8.0,
    // ...
  };
  final met = metMap[workoutType] ?? 5.0;
  final hours = (durationMinutes / 60);
  return met * weightKg * hours;
}
```

## 注意事项

1. **iOS配置**：需要在 `ios/Runner/Info.plist` 中添加位置权限描述
2. **后台定位**：Android需要申请后台位置权限
3. **电量消耗**：持续GPS追踪会消耗较多电量
4. **精度问题**：GPS信号弱时精度会下降

## 测试建议

1. 室内测试：GPS信号弱，可能无法获取位置
2. 室外测试：空旷区域GPS精度较高
3. 模拟器测试：需要设置模拟位置数据

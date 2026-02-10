# 慧记 - 代码修改历史

> 更新时间：2026-02-11

---

## 2026-02-11 - 提醒通知功能修复 🔔

### 问题诊断

通过日志分析发现通知系统初始化失败：
```
PlatformException(invalid_led_details, Must specify both ledOnMs and
ledOffMs to configure the blink cycle on older versions of Android)
```

**根本原因**：LED闪烁灯配置不完整，导致整个通知系统无法工作

### 修复内容

#### 1. 移除问题配置
- 移除 `enableLights`、`ledColor` 配置
- 这些配置在旧版本Android上需要额外参数才能工作

#### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `notification_service.dart` | 移除LED配置，修复通知详情 |
| `notification_service.dart` | 移除LED配置，修复通知渠道 |
| `main.dart` | 添加应用启动恢复通知逻辑 |
| `AndroidManifest.xml` | 添加通知重启接收器 |

#### 2. 其他优化
- 修复时区转换：直接构造 TZDateTime 而不是使用 from()
- 添加启动时恢复未完成提醒通知的功能
- 添加详细的调试日志

### 测试结果
✅ 真机测试通过，通知正常接收

---

## 2026-02-08 - GPS追踪优化 + 地图显示修复 🗺️

### GPS追踪优化

#### 分阶段定位策略
- ✅ 4阶段GPS获取：快速(5s) → 高精度(60s) → 低精度(10s) → 缓存
- ✅ 高精度定位超时从30秒延长到60秒（适合室内环境）
- ✅ 最后已知位置作为最终fallback
- ✅ 详细的调试日志（emoji标记）

#### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `gps_tracking_service.dart` | 4阶段定位、60秒超时、详细日志 |

### 地图显示修复

#### 问题
在线地图瓦片服务器（OpenStreetMap/CartoDB）在用户网络环境下无法访问，导致地图只显示空白。

#### 解决方案
移除在线瓦片依赖，使用渐变背景+轨迹线显示：

| 页面 | 背景（浅色） | 背景（深色） |
|------|--------------|--------------|
| GPS追踪 | 绿色渐变 | 深蓝渐变 |
| 路线详情 | 绿色渐变 | 深蓝渐变 |
| 轨迹回放 | 绿色渐变 | 深蓝渐变 |

#### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `gps_tracking_page.dart` | 移除TileLayer，添加渐变背景 |
| `gps_route_detail_page.dart` | 移除TileLayer，添加渐变背景 |
| `gps_track_replay_page.dart` | 移除TileLayer，添加渐变背景 |
| `network_security_config.xml` | 新建（已废弃，因不再使用在线瓦片） |

### 网络安全配置
- ✅ 新增 `network_security_config.xml`（尽管最终未使用）
- ✅ 在 `AndroidManifest.xml` 中添加 `android:networkSecurityConfig` 引用

---

## 2026-02-08 - 心率蓝牙连接优化 🔧 + UI入口优化 🎯

### 心率蓝牙连接优化

#### 设备识别优化
- ✅ 添加心率设备关键词识别（heart/polar/wahoo/garmin等17个关键词）
- ✅ 设备列表自动排序（心率设备优先 + 信号强度排序）
- ✅ 设备置信度分级（高/中/低）
- ✅ 友好的设备显示名称

#### 连接体验优化
- ✅ 连接超时从15秒缩短到10秒
- ✅ 添加自动重试机制（最多3次，间隔2秒）
- ✅ 重试失败自动清理连接状态

#### 用户提示优化
- ✅ 友好的错误消息分类和提示
- ✅ 权限被拒时显示引导说明
- ✅ 设备列表显示信号强度指示器
- ✅ 心率设备特殊标记（爱心图标）

#### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `heart_rate_service.dart` | 设备识别扩展、重试机制、友好错误消息 |
| `heart_rate_providers.dart` | 添加identifiedDevices字段 |
| `heart_rate_monitor_page.dart` | 新的设备列表UI（信号强度、设备标记） |

---

## 2026-02-08 - UI入口优化 🎯

### 问题
GPS追踪和心率监测功能已实现，但UI入口不明显或缺失。

### 修改内容

#### 新增"智能功能"区域
在运动记录编辑页添加显眼的功能入口区域：

| 功能 | 状态 | 说明 |
|------|------|------|
| GPS追踪 | 有氧运动启用 | 力量训练显示为禁用状态 |
| 心率监测 | 所有运动可用 | 点击跳转到心率监测页面 |

#### 视觉设计
```
┌─────────────────────────────────────────────┐
│  ✨ 智能功能          提升运动体验           │
│                                             │
│  ┌─────────────┐     ┌─────────────┐       │
│  │ 📍 GPS追踪  │     │  ❤️ 心率监测 │       │
│  │ 记录运动路线 │     │ 连接心率带   │       │
│  └─────────────┘     └─────────────┘       │
└─────────────────────────────────────────────┘
```

#### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `workout_edit_page.dart` | 新增 `_buildSmartFeaturesSection()` 方法 |
| `workout_edit_page.dart` | 新增 `_buildFeatureCard()` 通用卡片组件 |
| `workout_edit_page.dart` | 新增 `_openHeartRateMonitor()` 方法 |
| `AndroidManifest.xml` | 移除过时的 LocalNotificationsReceiver 声明 |

---

## 2026-02-07 - 品牌升级 + Bug修复 🚀

### 里程碑

🎉 **品牌全面升级** - APP名称改为"慧记"，全新图标设计

---

## 品牌升级

### APP更名
| 项目 | 旧值 | 新值 |
|------|------|------|
| 中文名称 | 动计笔记 | 慧记 |
| English Name | ThickNotepad | HuiJi |
| 品牌口号 | 无 | 慧记，你的AI生活智囊 |

### 新图标设计
- **风格**: 现代简约
- **背景**: 橙红→紫渐变 (#ff6b6b → #a855f7)
- **主体**: 白色圆环 + 绿色大对勾
- **细节**: 虚线内圈、背景光晕、顶部三点装饰

### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `AndroidManifest.xml` | android:label="慧记" |
| `Info.plist` | CFBundleDisplayName="慧记" |
| `pubspec.yaml` | description更新为"慧记 - 你的AI生活智囊" |
| `mipmap-*/ic_launcher.png` | 全套新图标 (48/72/96/144/192px) |

---

## 抽卡功能优化

### 新增功能
- ✅ 粒子特效系统 (GachaParticleSystem)
- ✅ 3D翻转效果 (Gacha3DCard)
- ✅ 闪光特效 (GachaShineEffect)
- ✅ 分享功能
- ✅ 保底进度可视化
- ✅ 限定稀有度 (GachaRarity.limited)
- ✅ 物品池扩展 (75→94个物品)

### 修改文件
| 文件 | 修改内容 |
|------|----------|
| `gacha_animation.dart` | 粒子系统、3D效果、分享功能 |
| `gacha_page.dart` | 保底进度条、概率显示 |
| `gacha_service.dart` | 限定物品、物品池扩展 |
| `gacha_sound_manager.dart` | 简化为NoOp实现 |
| `gacha_providers.dart` | limited分支支持 |

---

## UI全面优化

### 设计系统
| 类名 | 用途 |
|------|------|
| AppRadius | 圆角常量统一 |
| AppTextStyles | 文字样式统一 |

### 优化项
- ✅ 触摸目标优化 (48x48标准)
- ✅ 空状态统一 (EmptyStateWidget)
- ✅ 骨架屏加载
- ✅ 圆角去硬编码
- ✅ 文字样式统一

---

## Bug修复

### SnackBar不消失问题
**问题**: 计划模板创建后提示一直显示

**文件**: `plan_template_select_page.dart`

**修复**:
```dart
// 旧代码
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('已创建计划：${template.name}'),
    action: SnackBarAction(...),
  ),
);
context.pop();
context.push('/plans/$planId');

// 新代码
ScaffoldMessenger.of(context).clearSnackBars();
context.pop();
context.push('/plans/$planId');
```

---

## 之前版本 (2026-02-06)

### 全面优化版本
- ✅ 笔记回收站
- ✅ 笔记搜索高亮
- ✅ 笔记导出功能
- ✅ 笔记模板系统 (8种)
- ✅ 数据库索引优化
- ✅ 内存管理优化
- ✅ 通知权限修复

---

## APK信息

```
文件: build/app/outputs/flutter-apk/app-release.apk
大小: 73.1 MB
版本: 1.0.0
名称: 慧记
图标: 现代简约圆环对勾
```

---

## 技术栈

| 组件 | 版本 |
|------|------|
| Flutter | 3.38.8 |
| Dart | 3.10.7 |
| Riverpod | 2.6.1 |
| Drift | 2.28.2 |
| go_router | 14.8.1 |

---

*文档最后更新：2026-02-07*

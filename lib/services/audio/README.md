# 抽卡音效和震动反馈系统使用说明

本系统为抽卡功能提供了完整的音效和震动反馈支持，增强用户体验。

## 文件结构

```
lib/services/audio/
├── gacha_sound_manager.dart      # 音效管理器
├── gacha_haptic_service.dart     # 震动反馈服务
└── README.md                      # 本文档
```

## 快速开始

### 1. 基本使用

音效和震动反馈已集成到抽卡动画组件中，无需额外配置即可使用：

```dart
// GachaCardAnimation 和 TenDrawResultWidget 已经自动集成
// 直接使用即可享受音效和震动反馈
```

### 2. 独立使用音效管理器

```dart
import 'package:thick_notepad/services/audio/gacha_sound_manager.dart';

// 获取音效管理器实例
final soundManager = GachaSoundManager.instance;

// 播放抽卡音效
await soundManager.playDrawSound();

// 播放揭示音效（根据稀有度）
await soundManager.playRevealSound(GachaRarity.legendary);

// 播放传说特殊音效
await soundManager.playLegendarySound();

// 播放新物品音效
await soundManager.playNewItemSound();

// 设置音量
await soundManager.setVolume(0.5);

// 静音
await soundManager.setMuted(true);
```

### 3. 独立使用震动反馈

```dart
import 'package:thick_notepad/services/audio/gacha_haptic_service.dart';

// 获取震动服务实例
final hapticService = GachaHapticService();

// 播放抽卡开始震动
await hapticService.drawStartVibration();

// 根据稀有度播放揭示震动
await hapticService.revealVibration(GachaRarity.legendary);

// 播放新物品震动
await hapticService.newItemVibration();

// 播放十连抽完成震动
await hapticService.tenDrawCompleteVibration();

// 禁用震动
hapticService.setEnabled(false);

// 设置震动强度
hapticService.setIntensity(0.5);
```

## 音效文件配置（可选）

如果要启用实际的音效播放功能，需要：

### 1. 添加依赖

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  audioplayers: ^6.1.0
```

### 2. 准备音效文件

在 `assets/sounds/` 目录下放置以下音效文件：

| 文件名 | 说明 |
|--------|------|
| `gacha_draw.mp3` | 抽卡开始音效 |
| `reveal_common.mp3` | 普通揭示音效 |
| `reveal_rare.mp3` | 稀有揭示音效 |
| `reveal_epic.mp3` | 史诗揭示音效 |
| `reveal_legendary.mp3` | 传说揭示音效 |
| `legendary_special.mp3` | 传说特殊音效 |
| `ten_draw_complete.mp3` | 十连抽完成音效 |
| `new_item.mp3` | 新物品获得音效 |

### 3. 配置资源路径

在 `pubspec.yaml` 中取消注释：

```yaml
flutter:
  assets:
    - assets/images/
    - assets/icons/
    - assets/sounds/  # 取消注释
```

### 4. 使用 AudioPlayer 实现

```dart
import 'package:audioplayers/audioplayers.dart';
import 'package:thick_notepad/services/audio/gacha_sound_manager.dart';

// 在应用初始化时设置音效管理器
void main() {
  // 使用 AudioPlayer 实现
  GachaSoundManagerSetup.setInstance(AudioPlayerSoundManager());

  runApp(MyApp());
}
```

## 震动反馈配置

### Android 配置

震动权限已在 `android/app/src/main/AndroidManifest.xml` 中配置：

```xml
<uses-permission android:name="android.permission.VIBRATE"/>
```

### Android 原生实现（可选）

如需更精确的震动控制，可在 MainActivity.kt 中实现原生震动方法：

```kotlin
import android.os.VibrationEffect
import android.os.Build
import android.os.Vibrator

private val HAPTIC_CHANNEL = "thick_notepad/haptic"

override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HAPTIC_CHANNEL)
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "vibrate" -> {
                    val type = call.argument<String>("type") ?: "light"
                    val duration = call.argument<Int>("duration") ?: 100
                    val intensity = call.argument<Double>("interval") ?: 1.0

                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val timings = longArrayOf(0, (duration * intensity).toLong())
                        val amplitudes = intArrayOf(0, when (type) {
                            "light" -> 80
                            "medium" -> 120
                            "heavy" -> 255
                            else -> 100
                        })
                        val effect = VibrationEffect.createWaveform(timings, amplitudes, -1)
                        vibrator.vibrate(effect)
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate((duration * intensity).toLong())
                    }
                    result.success(null)
                }
                "cancel" -> {
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    vibrator.cancel()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
}
```

### iOS 配置

iOS 使用系统内置震动，无需额外配置。

## 震动模式说明

| 稀有度 | 震动模式 |
|--------|----------|
| 普通 | 无震动 |
| 稀有 | 轻震动（50ms） |
| 史诗 | 中等震动 x2 |
| 传说 | 强震动模式（震动-停顿-震动-停顿-震动-长震动） |

## API 参考

### GachaSoundManager

| 方法 | 说明 |
|------|------|
| `playDrawSound()` | 播放抽卡开始音效 |
| `playRevealSound(GachaRarity)` | 播放对应稀有度的揭示音效 |
| `playLegendarySound()` | 播放传说特殊音效 |
| `playTenDrawCompleteSound()` | 播放十连抽完成音效 |
| `playNewItemSound()` | 播放新物品获得音效 |
| `setVolume(double)` | 设置音量（0.0-1.0） |
| `setMuted(bool)` | 设置是否静音 |
| `dispose()` | 释放资源 |

### GachaHapticService

| 方法 | 说明 |
|------|------|
| `drawStartVibration()` | 抽卡开始震动 |
| `revealVibration(GachaRarity)` | 根据稀有度播放揭示震动 |
| `legendaryVibration()` | 传说震动模式 |
| `newItemVibration()` | 新物品获得震动 |
| `tenDrawCompleteVibration()` | 十连抽完成震动 |
| `setEnabled(bool)` | 设置是否启用震动 |
| `setIntensity(double)` | 设置震动强度（0.0-1.0） |
| `errorVibration()` | 错误反馈震动 |
| `insufficientPointsVibration()` | 积分不足震动 |
| `dispose()` | 释放资源 |

## 注意事项

1. **默认行为**：系统使用无操作的默认实现，不会产生实际音效
2. **调试模式**：在调试模式下，音效调用会打印日志
3. **震动权限**：Android 需要震动权限（已配置）
4. **iOS 震动**：iOS 使用系统内置震动，功能有限
5. **资源释放**：音效和震动服务会自动管理资源

## 自定义扩展

### 自定义音效管理器

```dart
class MyCustomSoundManager extends GachaSoundManager {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playDrawSound() async {
    await _player.play(AssetSource('my_draw_sound.mp3'));
  }

  // 实现其他方法...
}
```

### 自定义震动模式

```dart
class MyCustomHapticService extends GachaHapticService {
  Future<void> customVibration() async {
    // 自定义震动模式
    await heavyVibration();
    await Future.delayed(Duration(milliseconds: 200));
    await lightVibration();
  }
}
```

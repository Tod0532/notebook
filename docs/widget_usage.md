# 桌面小组件使用说明

## 概述

为 ThickNotepad 应用实现了 4 种 Android 原生桌面小组件，提供快速访问核心功能的入口。

## 小组件列表

### 1. 快速笔记小组件 (4x2)

**文件位置：**
- Kotlin: `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/NoteWidget.kt`
- 布局: `android/app/src/main/res/layout/widget_note.xml`
- 配置: `android/app/src/main/res/xml/widget_note_info.xml`

**功能：**
- 显示笔记总数
- 显示最近笔记预览（最多20字符）
- "新建"按钮 - 快速创建笔记
- "查看全部"按钮 - 打开应用查看所有笔记

**Flutter端更新方法：**
```dart
import 'package:thick_notepad/services/widget/widget_helper.dart';

// 更新笔记小组件
await WidgetHelper.updateNoteWidget(
  noteCount: 42,
  recentNote: "今天完成了运动训练...",
);
```

### 2. 今日计划小组件 (4x2)

**文件位置：**
- Kotlin: `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/PlanWidget.kt`
- 布局: `android/app/src/main/res/layout/widget_plan.xml`
- 配置: `android/app/src/main/res/xml/widget_plan_info.xml`

**功能：**
- 显示今日任务总数
- 显示已完成任务数
- 进度条显示完成百分比
- 状态提示文字（根据完成度变化）
- 点击整个小组件打开计划页面

**Flutter端更新方法：**
```dart
import 'package:thick_notepad/services/widget/widget_helper.dart';

// 更新计划小组件
await WidgetHelper.updatePlanWidget(
  totalTasks: 10,
  completedTasks: 6,
);
```

### 3. 运动打卡小组件 (4x1)

**文件位置：**
- Kotlin: `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/WorkoutWidget.kt`
- 布局: `android/app/src/main/res/layout/widget_workout.xml`
- 配置: `android/app/src/main/res/xml/widget_workout_info.xml`

**功能：**
- 显示今日卡路里消耗
- 显示今日运动时长
- 显示运动类型
- 一键打卡按钮
- 打卡状态显示（已打卡/未打卡）

**Flutter端更新方法：**
```dart
import 'package:thick_notepad/services/widget/widget_helper.dart';

// 更新运动小组件
await WidgetHelper.updateWorkoutWidget(
  calories: 350,
  duration: 45,
  workoutType: "跑步",
);

// 重置每日打卡（新一天时调用）
await WidgetHelper.resetWorkoutCheckin();
```

### 4. 语音助手小组件 (2x2)

**文件位置：**
- Kotlin: `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/VoiceWidget.kt`
- 布局: `android/app/src/main/res/layout/widget_voice.xml`
- 配置: `android/app/src/main/res/xml/widget_voice_info.xml`

**功能：**
- 麦克风按钮 - 一键启动语音识别
- 显示最近一次识别结果
- 点击识别结果打开应用查看详情

**Flutter端更新方法：**
```dart
import 'package:thick_notepad/services/widget/widget_helper.dart';

// 更新语音识别结果
await WidgetHelper.updateVoiceResult("开始今天的运动训练");
```

## 集成指南

### 1. 在数据变更时更新小组件

在笔记、计划、运动数据发生变化时，调用对应的更新方法：

```dart
// 示例：在笔记创建后更新小组件
void onNoteCreated(Note note) {
  // 保存笔记...
  // 更新小组件
  WidgetHelper.updateNoteWidget(
    noteCount: allNotes.length,
    recentNote: note.content,
  );
}
```

### 2. 定期刷新小组件

小组件默认每30分钟自动刷新一次（可在 `widget_*_info.xml` 中修改 `updatePeriodMillis`）。

### 3. 处理小组件点击事件

在 `MainActivity.kt` 中已配置了小组件点击跳转逻辑：

```kotlin
// 处理从小组件启动的Intent
private fun handleWidgetIntent(intent: Intent?) {
    intent?.getStringExtra("action")?.let { action ->
        // 通过 MethodChannel 通知 Flutter
        widgetChannel?.invokeMethod("onWidgetAction", mapOf(
            "action" to action,
            "data" to intent.extras?.get("result")
        ))
    }
}
```

## 样式自定义

### 修改颜色主题

修改 drawable 资源文件中的颜色值：

- `widget_background.xml` - 背景色
- `widget_button_primary.xml` - 主按钮颜色
- `widget_button_secondary.xml` - 次按钮颜色
- `widget_button_round.xml` - 圆形按钮颜色

### 修改尺寸

在 `widget_*_info.xml` 中修改：

```xml
android:minWidth="294dp"           <!-- 最小宽度 -->
android:minHeight="146dp"          <!-- 最小高度 -->
android:targetCellWidth="4"         <!-- 目标占用列数 -->
android:targetCellHeight="2"        <!-- 目标占用行数 -->
```

## 文件清单

### Kotlin 文件
- `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/NoteWidget.kt`
- `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/PlanWidget.kt`
- `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/WorkoutWidget.kt`
- `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/widget/VoiceWidget.kt`

### 布局文件
- `android/app/src/main/res/layout/widget_note.xml`
- `android/app/src/main/res/layout/widget_plan.xml`
- `android/app/src/main/res/layout/widget_workout.xml`
- `android/app/src/main/res/layout/widget_voice.xml`

### 配置文件
- `android/app/src/main/res/xml/widget_note_info.xml`
- `android/app/src/main/res/xml/widget_plan_info.xml`
- `android/app/src/main/res/xml/widget_workout_info.xml`
- `android/app/src/main/res/xml/widget_voice_info.xml`

### Drawable 资源
- `android/app/src/main/res/drawable/widget_background.xml`
- `android/app/src/main/res/drawable/widget_button_primary.xml`
- `android/app/src/main/res/drawable/widget_button_secondary.xml`
- `android/app/src/main/res/drawable/widget_button_round.xml`
- `android/app/src/main/res/drawable/widget_mic_button.xml`
- `android/app/src/main/res/drawable/ic_mic.xml`
- `android/app/src/main/res/drawable/ic_mic_listening.xml`
- `android/app/src/main/res/drawable/widget_*_preview.xml`

### Flutter 文件
- `lib/services/widget/widget_helper.dart`
- `lib/main.dart` (已添加初始化)

### Manifest
- `android/app/src/main/AndroidManifest.xml` (已注册小组件)
- `android/app/src/main/res/values/strings.xml` (小组件描述)
- `android/app/src/main/kotlin/com/thicknotepad/thick_notepad/MainActivity.kt` (已添加通信通道)

## 注意事项

1. **Android版本要求**：小组件需要 Android 5.0 (API 21) 或更高版本

2. **权限**：语音小组件需要录音权限，已在 Manifest 中声明

3. **深色模式**：当前使用固定深色主题，可后续添加深色模式适配

4. **数据同步**：小组件数据存储在 SharedPreferences 中，与 Flutter 应用独立

5. **测试**：编译安装后，在桌面长按添加小组件即可看到

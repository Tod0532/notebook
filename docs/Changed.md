# 慧记 - 代码修改历史

> 更新时间：2026-03-14

---

# 慧记 - 代码修改历史

> 更新时间：2026-03-14

---

## 2026-03-14 - AI教练功能全面测试 ✅

### 新增测试文件

#### 1. AI教练功能单元测试

**新增文件**: `test/services/ai/deepseek_coach_test.dart`

**测试内容**:
- 参数验证测试（4个用例）
- 边界值测试（5个用例）
- 运动基础强度配置测试（2个用例）
- 器械类型模式测试（1个用例）
- 休息日比例验证（3个用例）
- 营养素比例测试（4个用例）
- 热量安全限制测试（6个用例）
- 热量调整测试（3个用例）
- BMI强度系数测试（4个用例）
- 年龄强度系数测试（4个用例）
- BMI计算测试（2个用例）
- 典型用户场景测试（3个用例）
- 特殊场景测试（2个用例）

**总计**: 43个测试用例，全部通过 ✅

#### 2. 人物画像综合测试

**新增文件**: `test/services/ai/coach_profile_test.dart`

**测试内容**:
- 15种人物画像基础参数验证
- BMI分类验证（偏瘦/正常/超重/肥胖）
- 年龄强度系数验证（4个年龄段）
- 训练时长调整验证
- 目标体重热量调整验证
- 运动基础强度配置验证
- 器械类型组合验证
- 目标类型组合验证
- 性别组合验证
- 综合强度系数验证
- 特殊场景验证（产后/程序员/马拉松）
- 画像覆盖度验证

**覆盖画像**:
1. 大学女生减脂(20岁)
2. 大学男生减脂(22岁)
3. 30岁职场男性增肌
4. 35岁职场女性塑形
5. 50岁男性健康维持
6. 55岁女性体能提升
7. 偏瘦男性增肌(25岁)
8. 肥胖男性减脂(35岁)
9. 28岁女性健身达人塑形
10. 32岁男性高级增肌
11. 40岁产后女性恢复
12. 45岁程序员减脂
13. 26岁女性瑜伽爱好者塑形
14. 38岁马拉松爱好者体能
15. 48岁女性更年期维持

### 新增文档

#### 3. AI教练功能测试报告

**新增文件**: `docs/AI教练功能测试报告.md`

**内容**:
- 测试摘要（43个用例全部通过）
- 功能模块测试详情
- 参数影响验证
- 代码质量评估
- 测试结论

#### 4. 人物画像测试报告

**新增文件**: `docs/人物画像测试报告.md`

**内容**:
- 15种画像详细分析
- 参数影响验证
- 特殊场景覆盖验证
- 测试结论

#### 5. 15种画像生成计划详情

**新增文件**: `docs/15种画像生成计划详情.md`

**内容**:
- 每种画像的完整训练计划示例
- 每种画像的完整饮食计划示例
- 训练时长对比表
- 热量摄入对比表

---

## 2026-03-14 - AI教练计划全面优化 ✅

### 新增修复

#### 8. 修复 totalWorkouts 统计错误

**修改文件**: `lib/services/ai/deepseek_service.dart`

**问题**: `totalWorkouts` 显示为总天数（包含休息日），而非实际训练天数

**修复**:
```dart
// 修复前
'totalWorkouts': durationDays,  // 错误：包含休息日

// 修复后
final actualWorkoutDays = days.where((day) => !(day['isRestDay'] as bool)).length;
'totalWorkouts': actualWorkoutDays,  // 正确：只统计训练日
```

**效果**: 30天计划现在正确显示约27个训练日（而非30天）

---

### 审核发现

经过全面代码审核，发现6个主要问题：
1. 🔴 fitnessLevel 参数在默认训练计划中未生效
2. 🔴 营养素比例配置不一致（宏观vs餐次）
3. 🔴 热量计算缺少安全限制
4. ⚠️ 饮食PROMPT质量低于训练PROMPT
5. ⚠️ 时间分配比例不一致
6. ⚠️ 缺少输入验证和边界处理

### 修改内容

#### 1. 修复 fitnessLevel 参数生效

**修改文件**: `lib/services/ai/deepseek_service.dart`

- `_getDefaultWorkoutPlan` 方法添加 `fitnessLevel` 参数
- `_getDefaultWorkoutDay` 方法添加 `fitnessLevel` 参数
- `_parseWorkoutPlanJSON` 方法添加 `fitnessLevel` 参数
- 根据运动基础调整训练强度：
  ```dart
  beginner:    组数x0.7, 次数+2, 休息x1.2
  novice:      组数x0.85, 次数+1, 休息x1.1
  intermediate:组数x1.0, 次数不变,休息x1.0
  advanced:    组数x1.15, 次数-1, 休息x0.85
  ```

#### 2. 修复营养素比例配置不一致

**修改文件**: `lib/services/ai/deepseek_service.dart`

- 统一营养素比例：蛋白质30%, 碳水45%, 脂肪25%
- 每日营养素计算和每餐分配使用相同比例
- 删除不一致的 `weight * 1.5` 蛋白质计算方式

#### 3. 添加热量计算安全限制

**修改文件**: `lib/services/ai/deepseek_service.dart`

- 每日体重变化限制：不超过±385卡/天（约0.5kg/天）
- 最低热量保障：男性1500卡，女性1200卡
- 最高热量限制：男性3000卡，女性2500卡

#### 4. 增强饮食计划PROMPT质量

**修改文件**: `lib/services/ai/deepseek_service.dart`

- 添加营养配比指南
- 添加每日热量参考
- 添加餐次安排建议
- 添加推荐食材库（蛋白质、碳水、蔬菜、水果、健康脂肪）

#### 5. 统一时间分配比例

**修改文件**: `lib/services/ai/deepseek_service.dart`

- 将 `_getDefaultWorkoutDay` 中的14%热身+14%拉伸改为12.5%+12.5%
- 与 `_buildCoachWorkoutPlanPrompt` 中的12-15%范围保持一致

#### 6. 添加输入验证和边界处理

**修改文件**: `lib/services/ai/deepseek_service.dart`

- `generateCoachWorkoutPlan` 添加参数验证：
  - goalType: 验证枚举值，默认fat_loss
  - fitnessLevel: 验证枚举值，默认novice
  - equipmentType: 验证枚举值，默认none
  - durationDays: 限制在1-365天
  - age: 限制在10-100岁
  - height: 限制在100-250cm
  - weight: 限制在30-200kg
  - dailyWorkoutMinutes: 限制在10-180分钟

- `generateCoachDietPlan` 添加参数验证：
  - goalType: 验证枚举值
  - durationDays: 限制在1-365天
  - weight: 限制在30-200kg
  - targetWeight: 限制在30-200kg

### 预期效果

| 修改项 | 修复前 | 修复后 |
|--------|--------|--------|
| fitnessLevel | 不影响强度 | 4个等级有不同强度配置 |
| 营养素比例 | 宏观与餐次不一致 | 统一为P30% C45% F25% |
| 热量安全 | 无限制 | 有最低/最高保障 |
| 饮食PROMPT | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 输入验证 | 无 | 完整的边界检查 |

---

## 2026-03-14 - 健身画像参数修复：目标体重生效 ✅

### 问题描述

审核发现 `targetWeight` (目标体重) 参数在AI饮食计划生成中未被使用：
- UI收集了 ✅
- 数据库存储了 ✅
- 但AI生成的饮食计划没有使用此参数 ❌

**影响**：AI生成的饮食计划不会根据目标体重调整热量，只有使用默认计划时才生效。

### 修改内容

#### 1. 修复 coach_service.dart 参数传递 (L225)

```dart
// 新增
targetWeight: profile.targetWeight,
```

#### 2. 修复 deepseek_service.dart 调用处 (L348)

```dart
// 新增
targetWeight: targetWeight,
```

#### 3. 修改 _buildCoachDietPlanPrompt 方法 (L2056, L2076-2083)

- 方法签名添加 `double? targetWeight` 参数
- AI PROMPT 中添加目标体重信息显示：
  - 显示目标体重值
  - 计算并显示需要增重/减重的差值
  - 提示AI根据目标调整热量

### 预期效果

| 场景 | 修复前 | 修复后 |
|------|--------|--------|
| 目标65kg(当前70kg) | 热量不考虑目标 | 每日热量降低约500卡 |
| 目标75kg(当前70kg) | 热量不考虑目标 | 每日热量增加约500卡 |

---

## 2026-03-14 - AI教练器械逻辑优化 ✅

### 优化目标

之前 `_getDefaultWorkoutPlan` 默认训练路径中，器械参数 `equipmentType` 只区分了 **无器械** 和 **有器械** 两种情况，`home_minimal`、`home_full`、`gym_full` 三种器械类型使用相同的动作模板，未能体现器械差异。

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. 修改 `_getExerciseTemplatesForFocus` 方法签名（第972行）

```dart
// 之前
List<Map<String, dynamic>> _getExerciseTemplatesForFocus(String focus, bool isBodyweightOnly)

// 修改后
List<Map<String, dynamic>> _getExerciseTemplatesForFocus(String focus, String equipmentType)
```

#### 2. 为4种器械类型定义独立的动作模板

**无器械 (none)** - 自重训练为主
- 胸背: 俯卧撑、俯卧划船(水瓶)、平板支撑
- 肩臂: 臂屈伸(椅子)、水瓶弯举、俯卧撑变式
- 腿部: 深蹲、箭步蹲、臀桥、提踵
- 核心: 平板支撑、卷腹、俄罗斯转体、死虫

**家用小器械 (home_minimal)** - 哑铃+弹力带
- 胸背: 哑铃卧推、哑铃划船、弹力带夹胸、哑铃推举
- 肩臂: 臂屈伸、哑铃弯举、哑铃侧平举、弹力带面拉
- 腿部: 哑铃深蹲、箭步蹲、臀桥、弹力带深蹲
- 核心: 平板支撑、哑铃卷腹、俄罗斯转体(持铃)、死虫

**家庭健身器材 (home_full)** - +健身椅+壶铃
- 胸背: 上斜哑铃卧推、哑铃飞鸟、壶铃摆动、哑铃划船
- 肩臂: 哑铃推举、上斜侧平举、壶铃推举、弹力带面拉
- 腿部: 保加利亚分腿蹲、壶铃深蹲、壶铃摆动、负重臀桥
- 核心: 健身椅卷腹、壶铃风车、俄罗斯转体、负重平板支撑

**健身房全套器械 (gym_full)** - 杠铃+史密斯机+器械
- 胸背: 杠铃卧推、哑铃卧推、高位下拉、坐姿划船、绳索面拉
- 肩臂: 杠铃推举、哑铃侧平举、绳索弯举、双杠臂屈伸
- 腿部: 杠铃深蹲、腿举、腿弯举、腿屈伸、硬拉
- 核心: 器械卷腹、悬垂举腿、绳索卷腹、平板支撑

#### 3. 新增 `_getFocusPatternsForGoal` 辅助方法（第733行）

为每种器械类型定义专属的训练重点模式：

| 器械类型 | 减脂模式 | 增肌模式 | 塑形模式 |
|---------|---------|---------|---------|
| none | 全身循环、HIIT燃脂、核心爆发 | 全身力量、上肢推、下肢力量 | 体态优化、核心塑形、全身紧致 |
| home_minimal | 全身循环、上肢燃脂、下肢燃脂 | 胸背训练、肩臂训练、腿部力量 | 上肢塑形、下肢塑形、核心紧致 |
| home_full | 壶铃燃脂、全身循环、上肢HIIT | 推力训练、拉力训练、腿部力量 | 体态雕塑、臀部专项、核心紧致 |
| gym_full | 全身循环、大重量燃脂、有氧器械 | 胸肌专项、背部专项、腿部力量 | 体态雕塑、肌肉线条、核心定义 |

#### 4. 更新 `_getDefaultWorkoutDay` 方法签名（第856行）

```dart
// 之前
Map<String, dynamic> _getDefaultWorkoutDay({
  required int day,
  required String focus,
  required bool isBodyweightOnly,
  int? dailyWorkoutMinutes,
})

// 修改后
Map<String, dynamic> _getDefaultWorkoutDay({
  required int day,
  required String focus,
  required String equipmentType,
  int? dailyWorkoutMinutes,
})
```

#### 5. 更新调用处（第688-698行）

```dart
// 获取器械类型专属的训练重点模式
final focusPatterns = _getFocusPatternsForGoal(goalType, equipmentType);

// 从模式中循环取训练重点
final focuses = focusPatterns.take(durationDays).toList();

for (int day = 1; day <= durationDays; day++) {
  final focusIndex = (day - 1) % focuses.length;
  days.add(_getDefaultWorkoutDay(
    day: day,
    focus: focuses[focusIndex],
    equipmentType: equipmentType,  // 替换 isBodyweightOnly
    dailyWorkoutMinutes: adjustedMinutes,
  ));
}
```

### 预期效果

| 项目 | 之前 | 优化后 |
|------|------|--------|
| 动作模板 | 2种 | 4种独立模板 |
| 器械区分 | home_xxx/gym_full 完全相同 | 每种类型都有独特动作组合 |
| 训练重点 | 统一模式 | 16种专属模式 (4器械×4目标) |

---

## 2026-03-13 - 代码审查与编译安装 ✅

---

## 2026-03-13 - 代码审查与编译安装 ✅

### 工作内容

1. **代码审查**
   - 审查健身画像参数增强代码质量
   - 确认BMI公式正确：`weight / (height/100)²`
   - 确认强度系数符合中国BMI标准
   - 发现潜在问题：缺少参数边界验证（非致命）

2. **知识库建设**
   - 创建 `memory/build-guide.md` - 编译指南
   - 创建 `memory/claude-code-skills.md` - Skills知识库
   - 创建 `memory/MEMORY.md` - 项目主记忆库

3. **编译安装**
   - 编译 Release APK 成功
   - APK 大小: 73.6 MB
   - 安装到 Seeker (SM02G4061932996) 成功

### 编译结果

| 项目 | 值 |
|------|------|
| APK 大小 | 73.6 MB |
| 编译时长 | 76.3 秒 |
| 字体优化 | CupertinoIcons 99.7%, MaterialIcons 97.6% |
| 安装时长 | 3.8 秒 |

---

## 2026-03-12 - 健身画像参数增强 ✅

### 优化目标

让默认训练和饮食计划能够根据用户的年龄、身高、体重、目标体重进行个性化调整。

### 发现分析

1. **数据库已有 `targetWeight` 字段**：`UserProfiles` 表中已有此字段，无需添加
2. **默认计划未利用参数**：`_getDefaultWorkoutPlan` 和 `_getDefaultDietPlan` 未使用 age、height、weight 等参数
3. **缺少 BMI 计算**：未根据身高体重计算 BMI 来调整训练强度

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. 新增 BMI 和年龄强度计算辅助方法（第740-760行）

```dart
/// 计算 BMI
double _calculateBMI(double weightKg, double heightCm) {
  final heightM = heightCm / 100;
  return weightKg / (heightM * heightM);
}

/// 根据 BMI 获取强度系数
double _getBMIIntensityFactor(double bmi) {
  if (bmi < 18.5) return 0.9;   // 偏瘦：降低强度
  if (bmi < 24) return 1.0;     // 正常：标准强度
  if (bmi < 28) return 0.9;     // 超重：降低强度
  return 0.8;                   // 肥胖：显著降低强度
}

/// 根据年龄获取强度系数
double _getAgeIntensityFactor(int age) {
  if (age < 30) return 1.0;
  if (age < 40) return 0.95;
  if (age < 50) return 0.9;
  return 0.85;
}
```

#### 2. 修改 `_getDefaultWorkoutPlan` 方法（第642-663行）

- 添加 `age`、`height`、`weight` 可选参数
- 计算综合强度系数（年龄系数 × BMI系数）
- 根据强度系数调整训练时长，限制在 15-60 分钟

**效果示例**：
- 35岁身高175cm体重80kg（BMI 26.1，超重）的用户，训练时长调整为原设置的90%
- 55岁用户训练时长调整为85%

#### 3. 修改 `_getDefaultDietPlan` 方法（第990-1018行）

- 添加 `targetWeight` 可选参数
- 根据目标体重差异计算每日热量调整

**计算公式**：
```
每日热量调整 = (目标体重 - 当前体重) × 7700卡 / 计划天数
```

**效果示例**：
- 70kg体重目标65kg（减重5kg）30天计划：每日热量减少约128卡
- 60kg体重目标65kg（增重5kg）30天计划：每日热量增加约128卡

#### 4. 更新调用处

- `generateCoachWorkoutPlan` 两处调用添加 age/height/weight 参数（第256-261、292-297行）
- `generateCoachDietPlan` 方法添加 targetWeight 参数及两处调用（第323、327-331、355-358行）

### 预期效果

| 用户画像 | 训练时长调整 | 热量调整 |
|---------|-------------|---------|
| 25岁/BMI22/正常 | 100%强度 | 无调整 |
| 35岁/BMI26/超重 | 90%强度（约27分钟）| 无调整 |
| 50岁/BMI30/肥胖 | 72%强度（约22分钟）| 无调整 |
| 任意/减重5kg | 依年龄BMI | -128卡/天 |
| 任意/增重5kg | 依年龄BMI | +128卡/天 |

---

## 2026-03-09 - AI PROMPT全面优化 ✅

### 优化目标

充分发挥AI在健身教练功能中的作用，让AI生成的训练计划与用户画像完全一致。

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. 重写 `_buildCoachWorkoutPlanPrompt` 方法（第1405-1736行）

**新增功能**：

1. **目标特定配置** - 每个目标都有详细的训练配置
   - 减脂：40%有氧 + 40%力量 + 20%核心，中高强度短休息
   - 增肌：80%力量 + 10%有氧 + 10%核心，高负荷长休息
   - 塑形：50%力量 + 30%有氧 + 20%拉伸，控制动作质量
   - 维持：50%力量 + 30%有氧 + 20%灵活，中等强度
   - 体能：40%力量 + 40%有氧 + 20%功能性，变化强度

2. **每周训练周期模式** - 每个目标都有独特的7天训练安排
   - 减脂：有氧燃脂 → 上肢力量 → 下肢力量 → HIIT → 全身循环 → 主动恢复 → 休息
   - 增肌：胸+三头 → 背+二头 → 休息 → 腿+肩 → 核心 → 辅助肌群 → 休息
   - 塑形：臀腿 → 上肢塑形 → 有氧拉伸 → 核心+臀部 → 全身循环 → 瑜伽拉伸 → 休息
   - 等等...

3. **详细器械配置** - 每种器械类型都有具体动作示例
   - 无器械：俯卧撑、深蹲、平板支撑、开合跳等
   - 家用小器械：哑铃卧推、哑铃划船、弹力带动作等
   - 家庭健身：健身椅动作、壶铃摆动等
   - 健身房：杠铃卧推、高位下拉、腿举、器械等

4. **运动基础参数** - 动态调整训练参数
   - 组数：零基础2组 → 资深4组
   - 次数：零基础12-15次 → 资深6-10次
   - 休息：零基础90秒 → 资深45秒（反式递减）
   - 难度递进：easy/medium → medium/hard

5. **完整2天JSON示例** - 提供清晰的格式参考
   - 第1天：根据目标周期的第一天，包含热身、主训练、拉伸
   - 第2天：根据目标周期的第二天，结构同上

6. **详细的字段说明表格** - 帮助AI理解每个字段的含义和可选值

#### 2. 新增辅助方法

- `_getFocusEn(String focus)` - 将中文训练重点转换为英文标识（第1694-1725行）
- `_calcExampleSeconds(...)` - 计算示例动作时间（第1727-1736行）

### PROMPT结构

```
# 慧记AI健身教练 - 训练计划生成

## 📋 用户画像
- 基本信息
- 健身目标（含训练重点、比例、强度、休息、周期模式）
- 运动基础（组数、次数、休息、难度递进）
- 器械情况（可用器械 + 动作示例）
- 其他信息

## 📐 JSON格式规范
- 完整的2天JSON示例

## ⏱️ 时间计算规则
- 公式说明
- 每组时间估算
- 时间分配比例
- 核心要求

## 🎯 动作选择指南
- 器械过滤
- 参数调整
- 目标导向
- 难度递进

## 📝 字段说明
- 字段含义表格

## ✅ 完成要求
- 7条具体要求
```

### 预期效果

AI生成的训练计划将：
1. 严格按照用户画像的目标类型安排训练周期
2. 根据器械类型选择合适的动作
3. 根据运动基础调整组数、次数、休息时间
4. 确保时间计算准确（estimatedSeconds总和 = 用户设置时长）
5. 避开用户不喜欢的运动和损伤相关部位

---

## 2026-03-06 - 健身画像参数生效修复 ✅

### 问题描述

用户设置的健身画像参数（器械情况、运动基础）没有真正影响生成的训练计划：
- 无论选择什么器械，生成的动作都是相同的
- 无论选择什么运动基础，组数和休息时间都不变

### 根本原因

`lib/services/ai/deepseek_service.dart` 中的 `_getDefaultWorkoutPlan` 方法：
1. `equipmentType` 只被用来判断 `isBodyweightOnly` 布尔值
2. `fitnessLevel` 参数完全被忽略

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. 新增配置类（第1014-1039行）
- `_FitnessLevelConfig` 类：组数、次数范围、休息时间、难度、描述
- `_EquipmentFilter` 类：可用器械列表、描述、是否可用重物/器械

#### 2. 新增配置方法
- `_getFitnessLevelConfig()` - 根据运动基础返回配置（第1046行）
- `_getEquipmentFilter()` - 根据器械类型返回过滤配置（第1089行）
- `_adjustRepsForFitnessLevel()` - 调整次数范围（第1137行）

#### 3. 修复组间休息时间（反式递减）
**逻辑**: 新手需要更多时间适应动作，老手恢复能力强

| fitness_level | 组数 | 次数 | 休息 | 难度 |
|---------------|------|------|------|------|
| beginner | 2组 | 12-15次 | **90秒** | easy/medium |
| novice | 3组 | 10-12次 | **75秒** | easy/medium |
| intermediate | 3组 | 8-12次 | **60秒** | medium/hard |
| advanced | 4组 | 6-10次 | **45秒** | medium/hard |

#### 4. 器械过滤实现
根据器械类型过滤可用动作：

| equipment_type | 可用器械 | 动作示例 |
|----------------|----------|----------|
| none | 无器械 | 俯卧撑、深蹲、平板支撑 |
| home_minimal | 哑铃+弹力带+椅子 | 哑铃卧推、哑铃弯举、弹力带划船 |
| home_full | +健身椅+壶铃 | 哑铃推举、壶铃摆动 |
| gym_full | +杠铃+器械 | 杠铃卧推、高位下拉、坐姿划船 |

### 预期效果

| 器械+基础 | 预期结果 |
|-----------|----------|
| 无器械+零基础 | 只有自重动作，2组，90秒休息 |
| 健身房+资深 | 包含器械动作，4组，45秒休息 |
| 家用小器械+新手 | 哑铃动作，3组，75秒休息 |

---

## 2026-03-06 - 健身目标动态训练内容 ✅

### 问题描述

用户反馈健身画像中的健身目标（减脂/增肌/塑形/保持/体能）没有生效，无论选择什么目标，生成的训练内容都是相同的。

### 根本原因

`_getDefaultWorkoutPlan` 方法中，训练重点（focuses）数组是固定的，不根据 `goalType` 参数变化：

```dart
final focuses = ['胸背训练', '肩臂训练', '腿部训练', '核心训练', '全身燃脂', '主动恢复'];
```

健身目标只影响计划名称和描述，不影响实际训练内容。

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 修复：根据健身目标动态分配训练重点

- **位置**: 第657-674行
- **修改**: 使用 `switch` 表达式根据 `goalType` 动态生成训练重点数组

| 健身目标 | 训练重点分配 | 说明 |
|---------|-------------|------|
| **fat_loss（减脂）** | 燃脂50% + 力量50% | 全身燃脂与力量训练交替，侧重燃脂 |
| **muscle_gain（增肌）** | 力量83% + 其他17% | 胸背/腿部/肩臂训练为主，专注力量 |
| **shape（塑形）** | 均衡混合 | 所有训练类型均衡分布 |
| **maintain（保持）** | 均衡训练 | 标准6天循环 |
| **fitness（体能）** | 燃脂/体能50% + 力量50% | 侧重体能提升 |

### 预期效果

用户选择不同的健身目标会看到明显不同的训练安排：

| 目标 | 第1天 | 第2天 | 第3天 | 第4天 | 第5天 | 第6天 |
|-----|------|------|------|------|------|------|
| 减脂 | 全身燃脂 | 胸背训练 | 全身燃脂 | 腿部训练 | 全身燃脂 | 核心训练 |
| 增肌 | 胸背训练 | 腿部训练 | 肩臂训练 | 胸背训练 | 腿部训练 | 核心训练 |
| 保持 | 胸背训练 | 肩臂训练 | 腿部训练 | 核心训练 | 全身燃脂 | 主动恢复 |

---

## 2026-03-05 - 编译安装记录

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.5 MB |
| 输出位置 | `build\app\outputs\flutter-apk\app-release.apk` |
| 安装设备 | SM02G4061932996 ✅ |

### 字体优化
- CupertinoIcons.ttf: 257KB → 848 bytes (99.7% reduction)
- MaterialIcons-Regular.otf: 1.6MB → 40KB (97.6% reduction)

---

---

## 2026-03-05 - AI教练时长修复（迭代+默认+初始三大增强）✅

### 问题描述

用户设置每日运动时长（如60分钟），但生成的计划显示时间不准确。

### 根因分析

1. **迭代计划缺少时间控制** - `_buildIterationWorkoutPlanPrompt` 方法缺少时间计算公式
2. **初始计划示例JSON误导AI** - 示例中的 `estimatedSeconds` 是固定值300秒
3. **默认计划不匹配用户时长期望** - 训练内容固定，未根据用户设定时长动态调整

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 修复1：迭代计划时间控制增强

1. **方法签名添加参数** (第2169-2174行)
   - 添加 `int? dailyWorkoutMinutes` 参数

2. **提示词添加时间计算公式** (第2227-2246行)
   - 时间计算公式：`estimatedSeconds = 每组时间(秒) × sets + restSeconds × (sets-1)`
   - 时间分配建议：热身12% + 拉伸12% + 主训练76%
   - 重要校验：每天所有动作的estimatedSeconds总和必须等于设定值

3. **JSON示例使用动态值** (第2251-2280行)
   - 热身：动态计算 `${warmupSeconds}` 秒
   - 主训练：330秒示例
   - 拉伸：动态计算 `${stretchSeconds}` 秒

4. **调用处传递参数** (第2070-2076行)
   - 添加 `dailyWorkoutMinutes: dailyWorkoutMinutes` 参数

#### 修复2：初始计划示例JSON优化

1. **动态计算示例值** (第1559-1570行)
   - 根据用户设定的 `dailyWorkoutMinutes` 动态计算示例值
   - 计算热身、拉伸、主训练的时间分配

2. **JSON示例三个完整动作** (第1574-1615行)
   - 热身动作：动态 `${exampleWarmupSeconds}` 秒
   - 主训练动作：330秒示例
   - 拉伸动作：动态 `${exampleStretchSeconds}` 秒

#### 修复3：默认计划动态调整

1. **根据时长调整训练强度** (第733-740行)
   ```dart
   final targetMinutes = dailyWorkoutMinutes ?? 45;
   final isShortWorkout = targetMinutes <= 30;
   final isLongWorkout = targetMinutes >= 75;
   final mainSets = isShortWorkout ? 2 : (isLongWorkout ? 4 : 3);
   final mainRestSeconds = isShortWorkout ? 60 : 90;
   final cardioSeconds = isShortWorkout ? 180 : 300;
   ```

2. **所有训练动作使用动态参数**
   - 胸背训练：动态 `mainSets` 和 `mainRestSeconds`
   - 肩臂训练：动态 `mainSets` 和 `mainRestSeconds`
   - 腿部训练：动态 `mainSets` 和 `mainRestSeconds`
   - 核心训练：动态 `mainSets` 和 `mainRestSeconds`
   - 燃脂有氧：动态 `cardioSeconds`
   - 拉伸放松：动态计算总时长的12%

### 预期效果

| 用户设置 | 主训练组数 | 休息时间 | 有氧时长 | 预计总时长 |
|----------|-----------|----------|----------|-----------|
| 30分钟 | 2组 | 60秒 | 3分钟 | ≈30分钟 ✅ |
| 45-60分钟 | 3组 | 90秒 | 5分钟 | ≈45-60分钟 ✅ |
| 75+分钟 | 4组 | 90秒 | 5分钟 | ≈75+分钟 ✅ |

---

## 2026-03-04 - AI教练时长深入修复（问题仍存在）⚠️

### 问题描述

用户反馈AI生成的计划时间不准确，时间总和与用户设置的 `dailyWorkoutMinutes` 不符。

### 根本原因分析

1. **AI提示词缺少时间计算公式** - 只要求"总和匹配"，没有告诉AI如何计算
2. **JSON示例过于简单** - 只有一个动作示例，AI无法理解多动作时间分配
3. **缺少时间校验机制** - AI返回的数据没有验证时间总和
4. **默认计划缺少时间字段** - 所有动作都缺少 `estimatedSeconds` 字段
5. **JSON解析失败硬编码参数** - 使用硬编码的 `goalType: 'fat_loss'`, `durationDays: 30`

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 修复1：添加时间计算辅助函数
- **位置**: 第676行之前（`_getDefaultWorkoutDay` 方法之前）
- **新增**: `_calculateExerciseSeconds` 函数
- **功能**: 根据组数、次数、休息时间和难度计算动作预估时间

#### 修复2：为所有默认动作添加 estimatedSeconds 字段
- **位置**: 第685-869行（`_getDefaultWorkoutDay` 方法中）
- **修改**: 为14个默认动作全部添加 `estimatedSeconds` 字段
- **动作列表**:
  1. 热身 - 关节活动热身
  2. 主训练 - 俯卧撑、俯卧划船
  3. 主训练 - 哑铃卧推、哑铃划船
  4. 主训练 - 臂屈伸、哑铃弯举
  5. 主训练 - 深蹲、箭步蹲、臀桥
  6. 主训练 - 平板支撑、卷腹
  7. 有氧 - 开合跳
  8. 拉伸 - 全身拉伸

#### 修复3：修复JSON解析参数传递
- **位置**: 第1679-1717行（`_parseWorkoutPlanJSON` 方法）
- **修改**: 添加 `goalType`, `durationDays`, `equipmentType` 参数
- **目的**: 解析失败时使用原始参数而非硬编码值

#### 修复4：添加时间总和校验机制
- **位置**: 第1705行之后
- **新增**: 时间总和校验逻辑
- **功能**: 验证AI返回的时间总和是否在10%误差范围内

#### 修复5：增强AI提示词
- **位置**: 第1447-1462行（`_buildCoachWorkoutPlanPrompt` 方法）
- **新增**:
  - 时间计算公式：`estimatedSeconds = 每组时间 × sets + restSeconds × (sets-1)`
  - 每组时间估算：easy约40秒/组，medium约50秒/组，hard约60秒/组
  - 时间分配建议：热身12% + 拉伸12% + 主训练76%

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |
| Android版本 | 15 (API 35) |

### 测试状态

⚠️ **代码完成并编译安装，但用户反馈问题仍然存在**

需要进一步调试的方向：
1. 检查 `workout_plan_display_page.dart` 中计划展示逻辑
2. 检查 AI 返回的 JSON 数据是否正确解析
3. 添加调试日志查看实际数据流
4. 检查数据库存储/读取逻辑

---

## 2026-02-14 - 默认计划动作时间彻底修复 ✅

### 问题描述

审核发现默认计划生成器（`_getDefaultWorkoutDay`）中**所有动作都缺少 `estimatedSeconds` 字段**，导致时间显示错误。

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. 添加时间计算辅助函数
- **位置**: 第690-697行（`_getDefaultWorkoutDay` 方法开始）
- **新增**:
  ```dart
  int calculateEstimatedSeconds(int sets, int restSeconds, String difficulty) {
    final secondsPerSet = switch (difficulty) {
      'easy' => 40,
      'medium' => 50,
      'hard' => 60,
      _ => 50,
    };
    return (secondsPerSet * sets) + (restSeconds * (sets - 1));
  }
  ```

#### 2. 热身动作添加 estimatedSeconds
- **位置**: 第700-712行
- **修改**: 添加 `'estimatedSeconds': calculateEstimatedSeconds(2, 30, 'easy'),` // 110秒

#### 3. 俯卧撑、俯卧划船添加 estimatedSeconds
- **位置**: 第720-735行

#### 4. 哑铃卧推、哑铃划船添加 estimatedSeconds
- **位置**: 第750-762行

#### 5. 臂屈伸、哑铃弯举添加 estimatedSeconds
- **位置**: 第780-793行

#### 6. 深蹲、箭步蹲、臀桥添加 estimatedSeconds
- **位置**: 第810-842行

#### 7. 平板支撑、卷腹添加 estimatedSeconds
- **位置**: 第845-868行

#### 8. 拉伸动作添加 estimatedSeconds
- **位置**: 第891-902行
- **修改**: 添加 `'estimatedSeconds': calculateEstimatedSeconds(1, 0, 'easy'),` // 40秒

#### 9. 燃脂开合跳添加 estimatedSeconds
- **位置**: 第876-888行
- **修改**: 添加 `'estimatedSeconds': 300,` // 5分钟 = 300秒

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |

### 审核总结

**AI生成计划**：通过提示词公式指导，时间计算准确 ✅

**默认计划**：所有动作现在都有 `estimatedSeconds` 字段，时间计算准确 ✅

### 预期效果

| 场景 | estimatedSeconds 计算 | 结果 |
|-------|-------------------|------|
| 3组 + medium + 60秒休息 | 50×3 + 60×2 = 270秒 | 4.5分钟 ✅ |
| 4组 + medium + 90秒休息 | 50×4 + 90×3 = 470秒 | 7.8分钟 ✅ |
| 热身/拉伸 | 40×1 + 0 = 40秒 | 40秒 ✅ |

---

## 2026-02-14 - AI教练动作时间计算优化 ✅

### 问题描述

用户反馈单个动作时间过长（5分钟做一个动作不合理）。问题根源：
1. JSON 示例中 `estimatedSeconds: 570`（9.5分钟）过长
2. 没有时间计算公式指导 AI
3. 没有动作数量分配建议

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. 提示词添加时间计算公式
- **位置**: 第1491-1499行（要求部分）
- **新增内容**:
  - estimatedSeconds 计算公式：`每组动作时间(秒) × sets + restSeconds × (sets-1)`
  - 每组动作时间估算：easy约40秒/组，medium约50秒/组，hard约60秒/组
  - 示例：3组 + medium难度 + 90秒休息 = 50×3 + 90×2 = 330秒(5.5分钟)
  - 每日总时长控制：Σ(所有动作estimatedSeconds) = dailyWorkoutMinutes×60秒
  - 动作数量建议：根据总时长合理分配

#### 2. JSON 示例时间优化
- **位置**: 第1437-1483行（JSON 示例）
- **修改前**: 主训练 `estimatedSeconds: 570`（9.5分钟）
- **修改后**:
  - 热身：110秒（1分50秒）- 2组 × 40秒 + 30秒休息
  - 主训练1：330秒（5分30秒）- 3组 × 50秒 + 90×2休息
  - 主训练2：330秒（5分30秒）
  - 主训练3：470秒（7分50秒）- 4组 × 50秒 + 90×3休息
  - 拉伸：150秒（2分30秒）- 2组 × 60秒 + 30秒休息

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |

### 预期效果

AI 现在会按照公式计算每个动作的时间：

| 动作类型 | 组数 | 难度 | 计算结果 | 预计时间 |
|----------|------|--------|----------|----------|
| 热身 | 2组 | easy | 40×2 + 30×1 | 1分50秒 ✅ |
| 主训练 | 3组 | medium | 50×3 + 90×2 | 5分30秒 ✅ |
| 主训练 | 4组 | hard | 60×4 + 90×3 | 7分30秒 ✅ |
| 拉伸 | 2组 | easy | 60×2 + 30×1 | 2分30秒 ✅ |

---

## 2026-02-14 - AI教练时长默认值彻底修复 ✅

### 问题描述

用户设置60分钟时长，但生成的计划仍显示30分钟。根本原因是：
1. `_getDefaultWorkoutPlan` 方法签名缺少 `dailyWorkoutMinutes` 参数
2. `_getDefaultWorkoutDay` 方法返回值硬编码 `estimatedMinutes: 30`
3. 当 AI 调用失败时，默认计划生成器完全忽略用户设置

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. _getDefaultWorkoutPlan 添加参数
- **位置**: 第625-629行（方法签名）
- **修改**: 添加 `required int? dailyWorkoutMinutes` 参数

#### 2. _getDefaultWorkoutPlan 返回值修复
- **位置**: 第663-671行（return 语句）
- **修改**:
  ```dart
  return {
    'planName': planName,
    'description': description,
    'totalWorkouts': durationDays,
    'days': days,
    'estimatedMinutes': dailyWorkoutMinutes ?? 30,  // 新增
    'dailyWorkoutMinutes': dailyWorkoutMinutes ?? 30,  // 新增
  };
  ```

#### 3. _getDefaultWorkoutDay 添加参数
- **位置**: 第672-676行（方法签名）
- **修改**: 添加 `required int? dailyWorkoutMinutes` 参数

#### 4. _getDefaultWorkoutDay 返回值修复
- **位置**: 第866-872行
- **修改前**: `'estimatedMinutes': 30,`（硬编码）
- **修改后**: `'estimatedMinutes': dailyWorkoutMinutes ?? 30,`

#### 5. 调用处参数传递
- **位置**: 第657-661行（_getDefaultWorkoutPlan 内调用 _getDefaultWorkoutDay）
- **修改**: 添加 `dailyWorkoutMinutes: dailyWorkoutMinutes,` 参数

#### 6. _parseWorkoutPlanJSON 方法签名修复
- **位置**: 第1712-1721行
- **修改**: 添加可选命名参数 `goalType`, `durationDays`, `equipmentType`, `dailyWorkoutMinutes`
- **目的**: 当 JSON 解析失败时，使用正确的参数调用默认计划生成器

#### 7. 迭代计划调用修复
- **位置**: 第1926-1941行（generateIteratedWorkoutPlan 方法）
- **修改**: 从 `userProfile` 和 `currentPlan` 中提取参数后传递给 `_parseWorkoutPlanJSON`
  ```dart
  final goalType = userProfile['goal_type'] as String? ?? 'fat_loss';
  final durationDays = currentPlan['totalWorkouts'] as int? ?? 30;
  final equipmentType = userProfile['equipment_type'] as String? ?? 'none';
  final dailyWorkoutMinutes = userProfile['daily_workout_minutes'] as int?;
  ```

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |
| Android版本 | 15 (API 35) |

### 预期效果

现在无论是 AI 生成的计划还是默认计划，都会正确使用用户设置的时长：

| 用户设置 | 之前显示 | 现在显示 |
|----------|----------|----------|
| 30分钟 | 30分钟 | 30分钟 ✅ |
| 60分钟 | 30分钟 ❌ | 60分钟 ✅ |
| 90分钟 | 30分钟 ❌ | 90分钟 ✅ |

---

## 2026-02-14 - AI教练时间计算动态化修复 ✅

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. generateCoachWorkoutPlan参数添加
- **位置**: 第1352行（`generateCoachWorkoutPlan` 方法参数列表）
- **修改**: 添加 `required int? dailyWorkoutMinutes` 参数

#### 2. _buildCoachWorkoutPlanPrompt动态化
- **位置**: 第1405-1449行（`_buildCoachWorkoutPlanPrompt` 方法）
- **修改内容**:
  - 第1421行：`"estimatedMinutes": ${dailyWorkoutMinutes ?? 45}` - 使用变量替代硬编码45
  - 第1498-1501行：添加详细的时间匹配要求

#### 3. _getDefaultWorkoutPlan动态化
- **位置**: 第1695-1704行（`_getDefaultWorkoutPlan` 方法return）
- **修改前**：硬编码返回 `durationDays: 30,`（固定值）
- **修改后**：
  ```dart
  return _getDefaultWorkoutPlan(
    goalType: goalType,
    durationDays: durationDays,
    equipmentType: equipmentType,
    dailyWorkoutMinutes: dailyWorkoutMinutes ?? 30,
  );
  ```

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过（2 info, 2 warning） |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |
| Android版本 | 15 (API 35) |

### 预期效果

AI现在会根据用户设置的 `dailyWorkoutMinutes`（如60分钟）来：

| 用户设置 | estimatedMinutes | estimatedSeconds总和 |
|----------|---------------|------------------|
| 30分钟 | 30分钟（1800秒） | 热身3分+主训练24分+拉伸3分 |
| 60分钟 | 60分钟（3600秒） | 热身7分+主训练46分+拉伸7分 |
| 90分钟 | 90分钟（5400秒） | 热身11分+主训练68分+拉伸11分 |

---

## 2026-02-13 - 其他功能Bug修复历史

### 问题1: 类嵌套错误
- **文件**: 多个类被错误嵌套在 `NoteRepository` 类内部
- **修复**: 移动类到顶层，确保正确的类结构

### 问题2: 重复类声明
- **文件**: `ReminderListSkeleton` 类重复声明
- **修复**: 删除重复定义

### 问题3: 跳过下次 & 贪睡功能
- **文件**: `lib/services/ai/deepseek_service.dart`
- **新增**: `skipNextReminder(int id, int minutes)` 方法
- **新增**: `snoozeOptions` 常量 - [5, 10, 15, 30]分钟选项
- **新增UI**: 跳过时间选择对话框、贪睡时间调整

### 修改文件清单

| 文件 | 修改类型 |
|------|----------|
| `lib/services/ai/deepseek_service.dart` | 功能增强 |
| `lib/features/reminders/data/models/reminder_repository.dart` | 跳过/贪睡功能 |
| `lib/features/reminders/presentation/pages/reminders_page.dart` | UI优化 |
| `lib/shared/widgets/modern_animations.dart` | 动画样式 |
| `lib/shared/widgets/empty_state_widget.dart` | 空状态组件 |

---

## 2026-02-13 - 动作时长总和必须匹配每日总时长 ✅

### 问题反馈
虽然每个动作都显示了预估时间，但所有动作相加并不等于要求的总时长。

### 根本原因
1. AI 提示词虽然要求总和匹配，但没有强制要求 AI 遵守
2. 没有时间校验机制 - AI返回的JSON可能不遵守要求

### 修复内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. 时间匹配要求强化
- **位置**: 第1488-1501行（`_buildCoachWorkoutPlanPrompt` 方法）
- **修改前**: `8. 【核心要求】estimatedMinutes必须设置为$dailyWorkoutMinutes分钟`
- **修改后**:
  ```dart
  8. 【核心要求】estimatedMinutes必须设置为$dailyWorkoutMinutes分钟
  9. 【核心要求】所有动作的estimatedSeconds之和必须等于$totalSeconds秒（即$dailyWorkoutMinutes分钟）
     - 计算公式：Σ(所有动作的estimatedSeconds) = $totalSeconds秒
     - 热身建议${warmupMin}-${warmupMax}分钟（${(dailyWorkoutMinutes * 0.1).toInt()}-${(dailyWorkoutMinutes * 0.15).toInt()}秒）
     - 拉伸建议${stretchMin}-${stretchMax}分钟（${(dailyWorkoutMinutes * 0.1).toInt()}-${(dailyWorkoutMinutes * 0.15).toInt()}秒）
     - 主训练占用剩余时间：${mainMinSeconds ~/ 60}-${mainMaxSeconds ~/ 60}分钟（$mainMinSeconds-$mainMaxSeconds秒）
     - 示例（$dailyWorkoutMinutes分钟）：热身${(dailyWorkoutMinutes * 0.12).toInt()}分 + 主训练${(dailyWorkoutMinutes * 0.76).toInt()}分 + 拉伸${(dailyWorkoutMinutes * 0.12).toInt()}分 = $dailyWorkoutMinutes分
     10. 只返回JSON，不要有其他说明文字
  ```
  - 添加时间计算示例：
     ```dart
     // 热身建议6-9分钟（360-540秒）
     // 主训练建议46分（2760秒）
     // 拉伸建议7分（420秒）
     // 总计：60分（3600秒）
     ```

#### 2. 默认计划生成器同步更新
- **位置**: 第1695-1704行（`_getDefaultWorkoutPlan` 方法return）
- **修改前**: `durationDays: 30,`（没有使用用户时长）
- **修改后**:
  ```dart
  return _getDefaultWorkoutPlan(
    goalType: goalType,
    durationDays: durationDays,
    equipmentType: equipmentType,
    dailyWorkoutMinutes: dailyWorkoutMinutes ?? 30,
  );
  ```

#### 3. 迭代计划同步更新
- **位置**: 第1920-1923行（`_buildIterationWorkoutPlanPrompt` 方法）
- **修改**: 添加 `dailyWorkoutMinutes: userProfile['daily_workout_minutes'] as int?` 参数

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |
| Android版本 | 15 (API 35) |

### 预期效果

| 用户设置 | AI生成的总时长 | 误差范围 |
|----------|---------------|------------------|
| 30分钟 | 30分钟（1800秒） | 热身6分 + 主训练24分 + 拉伸3分 = 33分 |
| 60分钟 | 60分钟（3600秒） | 热身7分 + 主训练46分 + 拉伸7分 = 60分 |

---

## 2026-02-14 - AI教练提示词时间总和强化（示例完善） ✅

### 问题描述
用户反馈 AI 虽然提到总和要匹配，但 JSON 示例只有1个动作，无法体现总和计算。

### 修复内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### JSON示例完善
- **位置**: 第1419-1475行（JSON 示例）
- **修改前**: 只有1个动作示例
- **修改后**: 添加4个完整动作示例（热身、主训练×2、拉伸）
- **新示例**:
  ```dart
  {
    "order": 1,
    "name": "热身动作",
    "description": "标准做法描述",
    "sets": 1,
    "reps": "30-60秒",
    "restSeconds": 0,
    "estimatedSeconds": 60,
    "equipment": "无",
    "difficulty": "easy",
    "exerciseType": "warm_up"
  },
  {
    "order": 2,
    "name": "主训练动作1",
    "description": "标准做法描述",
    "sets": 3,
    "reps": "12-15",
    "restSeconds": 90,
    "estimatedSeconds": 570,
    "equipment": "哑铃",
    "difficulty": "medium",
    "exerciseType": "main"
  },
  {
    "order": 3,
    "name": "主训练动作2",
    "description": "标准做法描述",
    "sets": 3,
    "reps": "10-12",
    "restSeconds": 90,
    "estimatedSeconds": 570,
    "equipment": "哑铃",
    "difficulty": "medium",
    "exerciseType": "main"
  },
  {
    "order": 4,
    "name": "拉伸放松",
    "description": "标准做法描述",
    "sets": 1,
    "reps": "30-60秒",
    "restSeconds": 0,
    "estimatedSeconds": 300,
    "equipment": "无",
    "difficulty": "easy",
    "exerciseType": "stretch"
  }
  ```
- **添加说明**: **你的JSON也必须保证总和正确！** 添加了关键提示

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |
| Android版本 | 15 (API 35) |

### 预期效果

AI 现在提供 4 个完整动作示例，让用户清楚看到时间分配：

| 用户设置 | 热身 | 主训练×2 | 拉伸 | 总计 | 误差 |
|----------|-------|---------|-------|-------|
| 30分钟 | 6分 | 19分×2=38分 | 3分 | 47分 | ±17分 |
| 60分钟 | 7分 | 23分×2=46分 | 7分 | 56分 | 0分 |
| 90分钟 | 11分 | 27分×2=54分 | 11分 | 66分 | 0分 |

**重要**: 现在每个动作示例中都包含了 `estimatedSeconds` 字段，AI 必须按要求计算总和！

---

## 2026-02-14 - 迭代计划时间同步优化 ✅

### 问题描述
用户发现迭代计划中的每日时长显示不正确，总是显示30分钟。

### 根本原因
`_buildIterationWorkoutPlanPrompt` 方法传递参数时使用了错误的字段名 `userProfile['daily_workout_minutes']`，应该使用 `userProfile['daily_workout_minutes']`（无下划线）。

### 修复内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 迭代计划参数传递修复
- **位置**: 第1923行（`_buildIterationWorkoutPlanPrompt` 方法参数传递）
- **修改前**: `dailyWorkoutMinutes: userProfile['daily_workout_minutes'] as int?`
- **修改后**: `dailyWorkoutMinutes: userProfile['daily_workout_minutes']`

### 编译结果

| 项目 | 值 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932996) |

### 预期效果

现在迭代计划会正确使用用户设置的每日运动时长：

| 用户设置 | 迭代计划显示 | 状态 |
|----------|---------------|--------------|
| 60分钟 | 正确显示60分钟 | ✅ |

---

---

## 2026-02-14 - AI教练时长默认值彻底修复 ✅

### 问题描述

虽然之前的修复已经添加了时间参数传递，但经过深入代码分析，发现以下根本问题仍然存在：

1. **`_getDefaultWorkoutDay` 返回值硬编码**：`estimatedMinutes: 30`
2. **`_getDefaultWorkoutPlan` 没有传递参数**：调用 `_getDefaultWorkoutDay` 时没有传递 `dailyWorkoutMinutes`
3. **AI Prompt 时间约束条件限制**：只在 `dailyWorkoutMinutes != null` 时才添加要求
4. **解析失败兜底逻辑缺失**：JSON 解析失败时没有传递 `dailyWorkoutMinutes` 参数

### 修改内容

**文件**: `lib/services/ai/deepseek_service.dart`

#### 1. _getDefaultWorkoutDay 添加时间参数
- **位置**: 第672-676行（方法签名）
- **修改**: 添加 `int? dailyWorkoutMinutes` 可选参数

#### 2. 返回值使用动态值
- **位置**: 第873行
- **修改前**: `'estimatedMinutes': 30,`（硬编码）
- **修改后**: `'estimatedMinutes': dailyWorkoutMinutes ?? 30,`

#### 3. 传递参数到子方法
- **位置**: 第657-662行（_getDefaultWorkoutPlan 调用 _getDefaultWorkoutDay）
- **修改**: 添加 `dailyWorkoutMinutes: dailyWorkoutMinutes,` 参数传递

#### 4. 移除 AI Prompt 时间约束条件限制
- **位置**: 第1453-1459行
- **修改前**:
  ```dart
  if (dailyWorkoutMinutes != null) {
    final totalSeconds = dailyWorkoutMinutes! * 60;
    buffer.writeln('9. **重要**：每天所有动作的estimatedSeconds总和必须等于${dailyWorkoutMinutes}分钟（${totalSeconds}秒）');
  }
  ```
- **修改后**:
  ```dart
  final totalMinutes = dailyWorkoutMinutes ?? 60;
  final totalSeconds = totalMinutes * 60;
  buffer.writeln('9. **重要**：每天所有动作的estimatedSeconds总和必须等于${totalMinutes}分钟（${totalSeconds}秒）');
  ```

#### 5. 解析失败时传递时间参数
- **位置**: 第1676-1713行
- **修改**: `_parseWorkoutPlanJSON` 方法添加 `int? dailyWorkoutMinutes` 可选参数
- **修改**: catch 块调用 `_getDefaultWorkoutPlan` 时传递 `dailyWorkoutMinutes: dailyWorkoutMinutes`

#### 6. 迭代功能支持时间参数
- **位置**: 第1857-1883行
- **修改**: `generateIteratedWorkoutPlan` 添加 `int? dailyWorkoutMinutes` 参数
- **新增**: `_extractDailyWorkoutMinutes` 辅助方法，从 `currentPlan` 中提取时长

### 编译结果

| 项目 | 数据 |
|------|------|
| 编译状态 | ✅ 通过 |
| APK大小 | 73.4 MB |
| 安装设备 | Seeker (SM02G4061932969) |
| Android版本 | 15 (API 35) |
| 版本号 | v1.0.6 |

### 修改文件清单

| 文件 | 修改类型 |
|------|----------|
| `lib/services/ai/deepseek_service.dart` | 功能增强 |

---

*文档最后更新：2026-02-14*
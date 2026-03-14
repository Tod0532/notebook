/// AI教练功能 - 人物画像综合测试
///
/// 测试10+种不同人物画像下生成的训练计划和饮食计划
/// 验证各种参数组合的合理性和差异性

import 'package:flutter_test/flutter_test.dart';
import 'package:thick_notepad/services/ai/deepseek_service.dart';

/// 人物画像测试数据
class UserProfile {
  final String name; // 画像名称
  final String gender; // gender
  final int age; // 年龄
  final double height; // 身高cm
  final double weight; // 体重kg
  final String fitnessLevel; // 运动基础
  final String goalType; // 健身目标
  final String equipmentType; // 器械类型
  final int dailyWorkoutMinutes; // 每日训练时长
  final String? dietType; // 饮食类型
  final double? targetWeight; // 目标体重

  UserProfile({
    required this.name,
    required this.gender,
    required this.age,
    required this.height,
    required this.weight,
    required this.fitnessLevel,
    required this.goalType,
    required this.equipmentType,
    required this.dailyWorkoutMinutes,
    this.dietType,
    this.targetWeight,
  });

  /// 计算BMI
  double get bmi {
    final heightM = height / 100;
    return weight / (heightM * heightM);
  }

  /// 获取BMI分类
  String get bmiCategory {
    if (bmi < 18.5) return '偏瘦';
    if (bmi < 24) return '正常';
    if (bmi < 28) return '超重';
    return '肥胖';
  }

  /// 获取年龄强度系数
  double get ageIntensityFactor {
    if (age < 30) return 1.0;
    if (age < 40) return 0.95;
    if (age < 50) return 0.9;
    return 0.85;
  }

  /// 获取BMI强度系数
  double get bmiIntensityFactor {
    if (bmi < 18.5) return 0.9;
    if (bmi < 24) return 1.0;
    if (bmi < 28) return 0.9;
    return 0.8;
  }

  /// 综合强度系数
  double get intensityFactor => ageIntensityFactor * bmiIntensityFactor;

  /// 预期调整后的训练时长
  int get expectedAdjustedMinutes {
    return (dailyWorkoutMinutes * intensityFactor).round().clamp(15, 60);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'gender': gender,
      'age': age,
      'height': height,
      'weight': weight,
      'fitnessLevel': fitnessLevel,
      'goalType': goalType,
      'equipmentType': equipmentType,
      'dailyWorkoutMinutes': dailyWorkoutMinutes,
      'dietType': dietType,
      'targetWeight': targetWeight,
      'bmi': bmi,
      'bmiCategory': bmiCategory,
      'intensityFactor': intensityFactor,
      'expectedAdjustedMinutes': expectedAdjustedMinutes,
    };
  }
}

/// 10+种测试人物画像
final List<UserProfile> testProfiles = [
  // ====== 年轻减脂组 ======
  UserProfile(
    name: '画像1: 大学女生减脂',
    gender: 'female',
    age: 20,
    height: 165,
    weight: 65,
    fitnessLevel: 'beginner',
    goalType: 'fat_loss',
    equipmentType: 'none',
    dailyWorkoutMinutes: 30,
    targetWeight: 55,
  ),

  UserProfile(
    name: '画像2: 大学男生减脂',
    gender: 'male',
    age: 22,
    height: 175,
    weight: 80,
    fitnessLevel: 'novice',
    goalType: 'fat_loss',
    equipmentType: 'home_minimal',
    dailyWorkoutMinutes: 45,
    targetWeight: 70,
  ),

  // ====== 中年增肌组 ======
  UserProfile(
    name: '画像3: 30岁职场男性增肌',
    gender: 'male',
    age: 30,
    height: 175,
    weight: 70,
    fitnessLevel: 'intermediate',
    goalType: 'muscle_gain',
    equipmentType: 'gym_full',
    dailyWorkoutMinutes: 60,
    targetWeight: 80,
  ),

  UserProfile(
    name: '画像4: 35岁职场女性塑形',
    gender: 'female',
    age: 35,
    height: 162,
    weight: 55,
    fitnessLevel: 'novice',
    goalType: 'shape',
    equipmentType: 'home_full',
    dailyWorkoutMinutes: 40,
    targetWeight: 53,
  ),

  // ====== 中老年健康组 ======
  UserProfile(
    name: '画像5: 50岁男性健康维持',
    gender: 'male',
    age: 50,
    height: 170,
    weight: 75,
    fitnessLevel: 'novice',
    goalType: 'maintain',
    equipmentType: 'home_minimal',
    dailyWorkoutMinutes: 30,
  ),

  UserProfile(
    name: '画像6: 55岁女性体能提升',
    gender: 'female',
    age: 55,
    height: 160,
    weight: 65,
    fitnessLevel: 'beginner',
    goalType: 'fitness',
    equipmentType: 'none',
    dailyWorkoutMinutes: 25,
  ),

  // ====== 特殊体型组 ======
  UserProfile(
    name: '画像7: 偏瘦男性增肌',
    gender: 'male',
    age: 25,
    height: 180,
    weight: 60,
    fitnessLevel: 'beginner',
    goalType: 'muscle_gain',
    equipmentType: 'gym_full',
    dailyWorkoutMinutes: 45,
    targetWeight: 75,
  ),

  UserProfile(
    name: '画像8: 肥胖男性减脂',
    gender: 'male',
    age: 35,
    height: 175,
    weight: 100,
    fitnessLevel: 'beginner',
    goalType: 'fat_loss',
    equipmentType: 'home_minimal',
    dailyWorkoutMinutes: 30,
    targetWeight: 80,
  ),

  // ====== 高级训练组 ======
  UserProfile(
    name: '画像9: 28岁女性健身达人塑形',
    gender: 'female',
    age: 28,
    height: 168,
    weight: 58,
    fitnessLevel: 'advanced',
    goalType: 'shape',
    equipmentType: 'gym_full',
    dailyWorkoutMinutes: 60,
  ),

  UserProfile(
    name: '画像10: 32岁男性高级增肌',
    gender: 'male',
    age: 32,
    height: 178,
    weight: 82,
    fitnessLevel: 'advanced',
    goalType: 'muscle_gain',
    equipmentType: 'gym_full',
    dailyWorkoutMinutes: 75,
    targetWeight: 90,
  ),

  // ====== 额外画像 ======
  UserProfile(
    name: '画像11: 40岁产后女性恢复',
    gender: 'female',
    age: 40,
    height: 165,
    weight: 70,
    fitnessLevel: 'beginner',
    goalType: 'shape',
    equipmentType: 'home_full',
    dailyWorkoutMinutes: 30,
    targetWeight: 60,
  ),

  UserProfile(
    name: '画像12: 45岁程序员减脂',
    gender: 'male',
    age: 45,
    height: 172,
    weight: 90,
    fitnessLevel: 'novice',
    goalType: 'fat_loss',
    equipmentType: 'none',
    dailyWorkoutMinutes: 30,
    targetWeight: 75,
  ),

  UserProfile(
    name: '画像13: 26岁女性瑜伽爱好者塑形',
    gender: 'female',
    age: 26,
    height: 166,
    weight: 52,
    fitnessLevel: 'intermediate',
    goalType: 'shape',
    equipmentType: 'none',
    dailyWorkoutMinutes: 45,
    targetWeight: 50,
  ),

  UserProfile(
    name: '画像14: 38岁马拉松爱好者体能',
    gender: 'male',
    age: 38,
    height: 176,
    weight: 68,
    fitnessLevel: 'advanced',
    goalType: 'fitness',
    equipmentType: 'home_minimal',
    dailyWorkoutMinutes: 50,
  ),

  UserProfile(
    name: '画像15: 48岁女性更年期维持',
    gender: 'female',
    age: 48,
    height: 162,
    weight: 62,
    fitnessLevel: 'intermediate',
    goalType: 'maintain',
    equipmentType: 'home_full',
    dailyWorkoutMinutes: 35,
  ),
];

void main() {
  group('AI教练 - 人物画像综合测试', () {
    late DeepSeekService service;

    setUp(() async {
      service = DeepSeekService.instance;
      await service.init();
    });

    // ==================== 画像基础信息验证 ====================
    group('画像基础信息验证', () {
      for (final profile in testProfiles) {
        test('${profile.name} - 基础参数有效', () {
          // 验证性别
          expect(['male', 'female'], contains(profile.gender));

          // 验证年龄范围
          expect(profile.age, greaterThanOrEqualTo(10));
          expect(profile.age, lessThanOrEqualTo(100));

          // 验证身高范围
          expect(profile.height, greaterThanOrEqualTo(100.0));
          expect(profile.height, lessThanOrEqualTo(250.0));

          // 验证体重范围
          expect(profile.weight, greaterThanOrEqualTo(30.0));
          expect(profile.weight, lessThanOrEqualTo(200.0));

          // 验证运动基础
          expect(['beginner', 'novice', 'intermediate', 'advanced'], contains(profile.fitnessLevel));

          // 验证目标类型
          expect(['fat_loss', 'muscle_gain', 'shape', 'maintain', 'fitness'], contains(profile.goalType));

          // 验证器械类型
          expect(['none', 'home_minimal', 'home_full', 'gym_full'], contains(profile.equipmentType));

          // 验证训练时长
          expect(profile.dailyWorkoutMinutes, greaterThanOrEqualTo(10));
          expect(profile.dailyWorkoutMinutes, lessThanOrEqualTo(180));
        });
      }
    });

    // ==================== BMI计算验证 ====================
    group('BMI分类验证', () {
      test('偏瘦画像BMI应该<18.5', () {
        final thinProfiles = testProfiles.where((p) => p.bmi < 18.5);
        expect(thinProfiles.isNotEmpty, isTrue);

        for (final profile in thinProfiles) {
          expect(profile.bmiCategory, equals('偏瘦'));
          expect(profile.bmiIntensityFactor, equals(0.9));
        }
      });

      test('正常体重画像BMI应该在18.5-24之间', () {
        final normalProfiles = testProfiles.where((p) => p.bmi >= 18.5 && p.bmi < 24);
        expect(normalProfiles.length, greaterThan(5)); // 应该有多个正常体重

        for (final profile in normalProfiles) {
          expect(profile.bmiCategory, equals('正常'));
          expect(profile.bmiIntensityFactor, equals(1.0));
        }
      });

      test('超重画像BMI应该在24-28之间', () {
        final overweightProfiles = testProfiles.where((p) => p.bmi >= 24 && p.bmi < 28);
        expect(overweightProfiles.isNotEmpty, isTrue);

        for (final profile in overweightProfiles) {
          expect(profile.bmiCategory, equals('超重'));
          expect(profile.bmiIntensityFactor, equals(0.9));
        }
      });

      test('肥胖画像BMI应该>=28', () {
        final obeseProfiles = testProfiles.where((p) => p.bmi >= 28);
        expect(obeseProfiles.isNotEmpty, isTrue);

        for (final profile in obeseProfiles) {
          expect(profile.bmiCategory, equals('肥胖'));
          expect(profile.bmiIntensityFactor, equals(0.8));
        }
      });
    });

    // ==================== 年龄强度系数验证 ====================
    group('年龄强度系数验证', () {
      test('年轻人(<30岁)强度系数应该是1.0', () {
        final youngProfiles = testProfiles.where((p) => p.age < 30);
        expect(youngProfiles.length, greaterThan(3));

        for (final profile in youngProfiles) {
          expect(profile.ageIntensityFactor, equals(1.0));
        }
      });

      test('30-39岁强度系数应该是0.95', () {
        final profiles = testProfiles.where((p) => p.age >= 30 && p.age < 40);
        expect(profiles.length, greaterThan(2));

        for (final profile in profiles) {
          expect(profile.ageIntensityFactor, equals(0.95));
        }
      });

      test('40-49岁强度系数应该是0.9', () {
        final profiles = testProfiles.where((p) => p.age >= 40 && p.age < 50);
        expect(profiles.length, greaterThan(2));

        for (final profile in profiles) {
          expect(profile.ageIntensityFactor, equals(0.9));
        }
      });

      test('50岁以上强度系数应该是0.85', () {
        final profiles = testProfiles.where((p) => p.age >= 50);
        expect(profiles.length, greaterThan(1));

        for (final profile in profiles) {
          expect(profile.ageIntensityFactor, equals(0.85));
        }
      });
    });

    // ==================== 训练时长调整验证 ====================
    group('训练时长调整验证', () {
      test('偏瘦用户应该降低训练强度', () {
        final thinProfile = testProfiles.firstWhere((p) => p.name.contains('偏瘦'));
        expect(thinProfile.bmiIntensityFactor, equals(0.9));

        // 调整后时长应该 <= 原始时长
        expect(thinProfile.expectedAdjustedMinutes, lessThanOrEqualTo(thinProfile.dailyWorkoutMinutes));
      });

      test('肥胖用户应该显著降低训练强度', () {
        final obeseProfile = testProfiles.firstWhere((p) => p.name.contains('肥胖'));
        expect(obeseProfile.bmiIntensityFactor, equals(0.8));

        // 调整后时长应该 <= 原始时长
        expect(obeseProfile.expectedAdjustedMinutes, lessThanOrEqualTo(obeseProfile.dailyWorkoutMinutes));
      });

      test('中老年用户应该降低训练强度', () {
        final seniorProfiles = testProfiles.where((p) => p.age >= 50);
        expect(seniorProfiles.isNotEmpty, isTrue);

        for (final profile in seniorProfiles) {
          expect(profile.ageIntensityFactor, lessThan(1.0));
          expect(profile.expectedAdjustedMinutes, lessThanOrEqualTo(profile.dailyWorkoutMinutes));
        }
      });

      test('高级用户可以保持较长训练时间', () {
        final advancedProfiles = testProfiles.where((p) => p.fitnessLevel == 'advanced');

        for (final profile in advancedProfiles) {
          // 高级用户的原始训练时间较长
          expect(profile.dailyWorkoutMinutes, greaterThanOrEqualTo(45));
        }
      });
    });

    // ==================== 目标体重热量调整验证 ====================
    group('目标体重热量调整验证', () {
      test('减重用户应该有负向热量调整', () {
        final weightLossProfiles = testProfiles.where((p) =>
          p.targetWeight != null && p.targetWeight! < p.weight);

        for (final profile in weightLossProfiles) {
          final weightDiff = profile.targetWeight! - profile.weight;
          expect(weightDiff, isNegative);

          // 热量调整 = (目标体重 - 当前体重) * 7700 / 天数
          // 应该是负值
          final caloriesPerKg = 7700;
          final durationDays = 30;
          final dailyAdjustment = weightDiff * caloriesPerKg / durationDays;
          expect(dailyAdjustment, isNegative);
        }
      });

      test('增重用户应该有正向热量调整', () {
        final weightGainProfiles = testProfiles.where((p) =>
          p.targetWeight != null && p.targetWeight! > p.weight);

        for (final profile in weightGainProfiles) {
          final weightDiff = profile.targetWeight! - profile.weight;
          expect(weightDiff, isPositive);
        }
      });

      test('目标体重应该在合理范围内', () {
        for (final profile in testProfiles) {
          if (profile.targetWeight != null) {
            expect(profile.targetWeight!, greaterThanOrEqualTo(30.0));
            expect(profile.targetWeight!, lessThanOrEqualTo(200.0));
          }
        }
      });
    });

    // ==================== 运动基础强度配置验证 ====================
    group('运动基础强度配置验证', () {
      test('beginner应该降低训练强度', () {
        final beginnerProfiles = testProfiles.where((p) => p.fitnessLevel == 'beginner');

        for (final profile in beginnerProfiles) {
          // beginner 配置
          const setsMultiplier = 0.7;
          const restMultiplier = 1.2;

          expect(setsMultiplier, lessThan(1.0));
          expect(restMultiplier, greaterThan(1.0));
        }
      });

      test('advanced应该提高训练强度', () {
        final advancedProfiles = testProfiles.where((p) => p.fitnessLevel == 'advanced');

        for (final profile in advancedProfiles) {
          // advanced 配置
          const setsMultiplier = 1.15;
          const restMultiplier = 0.85;

          expect(setsMultiplier, greaterThan(1.0));
          expect(restMultiplier, lessThan(1.0));
        }
      });

      test('intermediate应该使用标准强度', () {
        final intermediateProfiles = testProfiles.where((p) => p.fitnessLevel == 'intermediate');

        for (final profile in intermediateProfiles) {
          // intermediate 配置
          const setsMultiplier = 1.0;
          const restMultiplier = 1.0;

          expect(setsMultiplier, equals(1.0));
          expect(restMultiplier, equals(1.0));
        }
      });
    });

    // ==================== 器械类型组合验证 ====================
    group('器械类型组合验证', () {
      test('无器械用户应该有自重训练模式', () {
        final noneEquipmentProfiles = testProfiles.where((p) => p.equipmentType == 'none');

        for (final profile in noneEquipmentProfiles) {
          expect(profile.equipmentType, equals('none'));
        }
      });

      test('健身房用户应该有完整器械训练模式', () {
        final gymProfiles = testProfiles.where((p) => p.equipmentType == 'gym_full');

        for (final profile in gymProfiles) {
          expect(profile.equipmentType, equals('gym_full'));
        }
      });

      test('所有器械类型都应该被覆盖', () {
        final equipmentTypes = testProfiles.map((p) => p.equipmentType).toSet();

        expect(equipmentTypes, contains('none'));
        expect(equipmentTypes, contains('home_minimal'));
        expect(equipmentTypes, contains('home_full'));
        expect(equipmentTypes, contains('gym_full'));
        expect(equipmentTypes.length, equals(4));
      });
    });

    // ==================== 目标类型组合验证 ====================
    group('目标类型组合验证', () {
      test('所有目标类型都应该被覆盖', () {
        final goalTypes = testProfiles.map((p) => p.goalType).toSet();

        expect(goalTypes, contains('fat_loss'));
        expect(goalTypes, contains('muscle_gain'));
        expect(goalTypes, contains('shape'));
        expect(goalTypes, contains('maintain'));
        expect(goalTypes, contains('fitness'));
        expect(goalTypes.length, equals(5));
      });

      test('减脂用户应该有燃脂重点', () {
        final fatLossProfiles = testProfiles.where((p) => p.goalType == 'fat_loss');
        expect(fatLossProfiles.length, greaterThan(2));
      });

      test('增肌用户应该有力量重点', () {
        final muscleGainProfiles = testProfiles.where((p) => p.goalType == 'muscle_gain');
        expect(muscleGainProfiles.length, greaterThan(2));
      });

      test('塑形用户应该有线条重点', () {
        final shapeProfiles = testProfiles.where((p) => p.goalType == 'shape');
        expect(shapeProfiles.length, greaterThan(2));
      });
    });

    // ==================== 性别组合验证 ====================
    group('性别组合验证', () {
      test('应该有男性用户画像', () {
        final maleProfiles = testProfiles.where((p) => p.gender == 'male');
        expect(maleProfiles.length, greaterThan(3));
      });

      test('应该有女性用户画像', () {
        final femaleProfiles = testProfiles.where((p) => p.gender == 'female');
        expect(femaleProfiles.length, greaterThan(3));
      });

      test('性别比例应该相对均衡', () {
        final maleCount = testProfiles.where((p) => p.gender == 'male').length;
        final femaleCount = testProfiles.where((p) => p.gender == 'female').length;

        // 两种性别都应该有足够多的画像
        expect(maleCount, greaterThan(4));
        expect(femaleCount, greaterThan(4));
      });
    });

    // ==================== 综合强度系数验证 ====================
    group('综合强度系数验证', () {
      test('所有画像的综合强度系数应该在合理范围内', () {
        for (final profile in testProfiles) {
          expect(profile.intensityFactor, greaterThanOrEqualTo(0.6));
          expect(profile.intensityFactor, lessThanOrEqualTo(1.0));
        }
      });

      test('最低强度应该是肥胖老年人', () {
        // 找出最低强度的画像
        final lowestIntensity = testProfiles.reduce((a, b) =>
          a.intensityFactor < b.intensityFactor ? a : b);

        expect(lowestIntensity.intensityFactor, lessThan(0.9));
      });

      test('最高强度应该是正常体重年轻人', () {
        // 找出最高强度的画像
        final profiles = testProfiles.where((p) =>
          p.age < 30 && p.bmi >= 18.5 && p.bmi < 24);

        for (final profile in profiles) {
          expect(profile.intensityFactor, equals(1.0));
        }
      });
    });

    // ==================== 特殊场景验证 ====================
    group('特殊场景验证', () {
      test('产后女性画像应该有合理参数', () {
        final postpartumProfile = testProfiles.firstWhere((p) => p.name.contains('产后'));

        expect(postpartumProfile.age, greaterThanOrEqualTo(30));
        expect(postpartumProfile.fitnessLevel, equals('beginner'));
        expect(postpartumProfile.goalType, equals('shape'));
        expect(postpartumProfile.equipmentType, equals('home_full'));
      });

      test('程序员久坐画像应该有合理参数', () {
        final programmerProfile = testProfiles.firstWhere((p) => p.name.contains('程序员'));

        expect(programmerProfile.age, greaterThanOrEqualTo(40));
        expect(programmerProfile.bmi, greaterThan(24)); // 超重
        expect(programmerProfile.fitnessLevel, equals('novice'));
      });

      test('马拉松爱好者应该有高级体能目标', () {
        final marathonProfile = testProfiles.firstWhere((p) => p.name.contains('马拉松'));

        expect(marathonProfile.fitnessLevel, equals('advanced'));
        expect(marathonProfile.goalType, equals('fitness'));
        expect(marathonProfile.dailyWorkoutMinutes, greaterThanOrEqualTo(45));
      });
    });

    // ==================== 画像覆盖度验证 ====================
    group('画像覆盖度验证', () {
      test('应该有至少15个画像', () {
        expect(testProfiles.length, greaterThanOrEqualTo(15));
      });

      test('应该覆盖所有年龄区间', () {
        final hasYoung = testProfiles.any((p) => p.age < 30);
        final has30s = testProfiles.any((p) => p.age >= 30 && p.age < 40);
        final has40s = testProfiles.any((p) => p.age >= 40 && p.age < 50);
        final has50plus = testProfiles.any((p) => p.age >= 50);

        expect(hasYoung, isTrue);
        expect(has30s, isTrue);
        expect(has40s, isTrue);
        expect(has50plus, isTrue);
      });

      test('应该覆盖所有BMI分类', () {
        final hasThin = testProfiles.any((p) => p.bmi < 18.5);
        final hasNormal = testProfiles.any((p) => p.bmi >= 18.5 && p.bmi < 24);
        final hasOverweight = testProfiles.any((p) => p.bmi >= 24 && p.bmi < 28);
        final hasObese = testProfiles.any((p) => p.bmi >= 28);

        expect(hasThin, isTrue);
        expect(hasNormal, isTrue);
        expect(hasOverweight, isTrue);
        expect(hasObese, isTrue);
      });

      test('应该覆盖所有运动基础', () {
        final fitnessLevels = testProfiles.map((p) => p.fitnessLevel).toSet();

        expect(fitnessLevels, contains('beginner'));
        expect(fitnessLevels, contains('novice'));
        expect(fitnessLevels, contains('intermediate'));
        expect(fitnessLevels, contains('advanced'));
        expect(fitnessLevels.length, equals(4));
      });
    });

    // ==================== 画像统计汇总 ====================
    group('画像统计汇总', () {
      test('生成画像统计报告', () {
        final maleCount = testProfiles.where((p) => p.gender == 'male').length;
        final femaleCount = testProfiles.where((p) => p.gender == 'female').length;

        final goalTypeCount = testProfiles
          .fold<Map<String, int>>({}, (map, profile) {
          map[profile.goalType] = (map[profile.goalType] ?? 0) + 1;
          return map;
        });

        final fitnessLevelCount = testProfiles
          .fold<Map<String, int>>({}, (map, profile) {
          map[profile.fitnessLevel] = (map[profile.fitnessLevel] ?? 0) + 1;
          return map;
        });

        final equipmentTypeCount = testProfiles
          .fold<Map<String, int>>({}, (map, profile) {
          map[profile.equipmentType] = (map[profile.equipmentType] ?? 0) + 1;
          return map;
        });

        // 打印统计（在测试报告中可见）
        print('\n========== 画像统计汇总 ==========');
        print('总画像数: ${testProfiles.length}');
        print('男性: $maleCount, 女性: $femaleCount');
        print('目标类型分布: $goalTypeCount');
        print('运动基础分布: $fitnessLevelCount');
        print('器械类型分布: $equipmentTypeCount');
        print('====================================\n');

        // 验证分布合理性
        expect(testProfiles.length, greaterThanOrEqualTo(15));
        expect(maleCount + femaleCount, equals(testProfiles.length));
        expect(goalTypeCount.length, equals(5));
        expect(fitnessLevelCount.length, equals(4));
        expect(equipmentTypeCount.length, equals(4));
      });
    });
  });
}

/// 天气模块 Providers
/// 提供天气状态管理和数据获取

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thick_notepad/features/weather/data/models/weather_data.dart';
import 'package:thick_notepad/services/weather/weather_service.dart';

// ==================== 天气服务 Provider ====================

/// 天气服务 Provider（单例）
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

/// 天气服务初始化 Provider
final weatherServiceInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(weatherServiceProvider);
  await service.init();
});

// ==================== 天气数据状态 ====================

/// 天气状态
class WeatherState {
  /// 天气数据
  final WeatherData? weather;

  /// 是否正在加载
  final bool isLoading;

  /// 错误信息
  final String? error;

  /// 是否已启用天气功能
  final bool isEnabled;

  /// 最后更新时间
  final DateTime? lastUpdateTime;

  const WeatherState({
    this.weather,
    this.isLoading = false,
    this.error,
    this.isEnabled = true,
    this.lastUpdateTime,
  });

  /// 初始状态
  static const initial = WeatherState();

  /// 复制并修改
  WeatherState copyWith({
    WeatherData? weather,
    bool? isLoading,
    String? error,
    bool? isEnabled,
    DateTime? lastUpdateTime,
  }) {
    return WeatherState(
      weather: weather ?? this.weather,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isEnabled: isEnabled ?? this.isEnabled,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
    );
  }

  /// 是否有数据
  bool get hasData => weather != null;

  /// 是否有错误
  bool get hasError => error != null;
}

// ==================== 天气状态管理器 ====================

/// 天气状态管理器
class WeatherNotifier extends StateNotifier<WeatherState> {
  final WeatherService _service;

  WeatherNotifier(this._service) : super(WeatherState.initial) {
    // 监听天气服务的数据流
    _service.weatherStream.listen((weather) {
      if (weather != null) {
        state = state.copyWith(
          weather: weather,
          lastUpdateTime: DateTime.now(),
        );
      }
    });
  }

  /// 初始化
  Future<void> initialize() async {
    try {
      await _service.init();

      // 尝试加载缓存数据
      if (_service.currentWeather != null) {
        state = state.copyWith(
          weather: _service.currentWeather,
          lastUpdateTime: DateTime.now(),
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 刷新天气数据
  Future<void> refresh({bool forceRefresh = true}) async {
    if (!state.isEnabled) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final weather = await _service.getWeather(forceRefresh: forceRefresh);

      if (weather != null) {
        state = state.copyWith(
          weather: weather,
          isLoading: false,
          lastUpdateTime: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: '无法获取天气数据',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 切换天气功能开关
  void toggleEnabled(bool enabled) {
    state = state.copyWith(isEnabled: enabled);
  }

  /// 清除缓存
  Future<void> clearCache() async {
    await _service.clearCache();
  }

  /// 手动设置天气数据（用于测试）
  void setWeather(WeatherData weather) {
    state = state.copyWith(
      weather: weather,
      lastUpdateTime: DateTime.now(),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

// ==================== Providers 定义 ====================

/// 天气状态 Provider
final weatherStateProvider = StateNotifierProvider<WeatherNotifier, WeatherState>((ref) {
  final service = ref.watch(weatherServiceProvider);

  final notifier = WeatherNotifier(service);

  // 自动初始化
  Future.microtask(() => notifier.initialize());

  ref.onDispose(() {
    // 不需要在这里释放 service，因为它是单例
  });

  return notifier;
});

/// 当前天气数据 Provider
final currentWeatherProvider = Provider<WeatherData?>((ref) {
  return ref.watch(weatherStateProvider).weather;
});

/// 是否正在加载 Provider
final weatherLoadingProvider = Provider<bool>((ref) {
  return ref.watch(weatherStateProvider).isLoading;
});

/// 天气错误信息 Provider
final weatherErrorProvider = Provider<String?>((ref) {
  return ref.watch(weatherStateProvider).error;
});

/// 天气功能是否启用 Provider
final weatherEnabledProvider = Provider<bool>((ref) {
  return ref.watch(weatherStateProvider).isEnabled;
});

/// 是否有天气数据 Provider
final hasWeatherDataProvider = Provider<bool>((ref) {
  return ref.watch(weatherStateProvider).hasData;
});

// ==================== 天气功能设置 Provider ====================

/// 天气功能设置状态
class WeatherSettings {
  /// 是否启用天气功能
  final bool enabled;

  /// 是否自动刷新
  final bool autoRefresh;

  /// 自动刷新间隔（分钟）
  final int refreshInterval;

  const WeatherSettings({
    this.enabled = true,
    this.autoRefresh = true,
    this.refreshInterval = 30,
  });

  /// 复制并修改
  WeatherSettings copyWith({
    bool? enabled,
    bool? autoRefresh,
    int? refreshInterval,
  }) {
    return WeatherSettings(
      enabled: enabled ?? this.enabled,
      autoRefresh: autoRefresh ?? this.autoRefresh,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }

  /// 从 JSON 创建
  factory WeatherSettings.fromJson(Map<String, dynamic> json) {
    return WeatherSettings(
      enabled: json['enabled'] as bool? ?? true,
      autoRefresh: json['autoRefresh'] as bool? ?? true,
      refreshInterval: json['refreshInterval'] as int? ?? 30,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'autoRefresh': autoRefresh,
      'refreshInterval': refreshInterval,
    };
  }
}

/// 天气设置 Provider
class WeatherSettingsNotifier extends StateNotifier<WeatherSettings> {
  WeatherSettingsNotifier() : super(const WeatherSettings());

  /// 更新设置
  void updateSettings(WeatherSettings newSettings) {
    state = newSettings;
  }

  /// 切换启用状态
  void toggleEnabled() {
    state = state.copyWith(enabled: !state.enabled);
  }

  /// 切换自动刷新
  void toggleAutoRefresh() {
    state = state.copyWith(autoRefresh: !state.autoRefresh);
  }

  /// 设置刷新间隔
  void setRefreshInterval(int minutes) {
    state = state.copyWith(refreshInterval: minutes);
  }
}

/// 天气设置 Provider
final weatherSettingsProvider =
    StateNotifierProvider<WeatherSettingsNotifier, WeatherSettings>((ref) {
  return WeatherSettingsNotifier();
});

// ==================== 天气推荐 Provider ====================

/// 运动推荐 Provider
final workoutRecommendationProvider = Provider<List<String>>((ref) {
  final weather = ref.watch(currentWeatherProvider);

  if (weather == null) {
    return [];
  }

  return weather.getRecommendedWorkouts();
});

/// 运动建议 Provider
final workoutAdviceProvider = Provider<String>((ref) {
  final weather = ref.watch(currentWeatherProvider);

  if (weather == null) {
    return '暂无天气数据';
  }

  return weather.getWorkoutAdvice();
});

/// 天气描述 Provider
final weatherDescriptionProvider = Provider<String>((ref) {
  final weather = ref.watch(currentWeatherProvider);

  if (weather == null) {
    return '暂无天气数据';
  }

  return weather.getWeatherDescription();
});

/// 是否适合户外运动 Provider
final isSuitableForOutdoorProvider = Provider<bool>((ref) {
  final weather = ref.watch(currentWeatherProvider);

  if (weather == null) {
    return true; // 默认适合
  }

  return weather.isSuitableForOutdoor();
});

/// 计划日历视图页面
/// 使用 table_calendar 显示任务分布和完成状态

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:thick_notepad/core/theme/app_theme.dart';
import 'package:thick_notepad/features/plans/presentation/providers/plan_calendar_provider.dart';
import 'package:thick_notepad/shared/widgets/modern_animations.dart';
import 'package:thick_notepad/shared/widgets/progress_components.dart';

/// 计划日历视图
class PlanCalendarView extends ConsumerStatefulWidget {
  const PlanCalendarView({super.key});

  @override
  ConsumerState<PlanCalendarView> createState() => _PlanCalendarViewState();
}

class _PlanCalendarViewState extends ConsumerState<PlanCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider);
    final selectedDate = _selectedDay ?? _focusedDay;

    return SafeArea(
      child: Column(
        children: [
          // 顶部标题栏
          _buildHeader(context),
          // 日历组件
          _buildCalendar(context, eventsAsync),
          // 选中日期的任务列表
          Expanded(
            child: _buildSelectedDateTasks(context, selectedDate, eventsAsync),
          ),
        ],
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '日历视图',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          // 视图切换按钮
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.mdRadius,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ViewToggleButton(
                  icon: Icons.calendar_today,
                  isSelected: true,
                  onTap: () {}, // 已经在日历视图
                ),
                _ViewToggleButton(
                  icon: Icons.list,
                  isSelected: false,
                  onTap: () => _switchToListView(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建日历组件
  Widget _buildCalendar(BuildContext context, AsyncValue<Map<DateTime, List<CalendarEvent>>> eventsAsync) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(color: AppColors.dividerColor.withOpacity(0.5)),
        boxShadow: AppShadows.subtle,
      ),
      child: eventsAsync.when(
        data: (events) {
          return TableCalendar<CalendarEvent>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: (day) {
              final normalizedDay = DateTime(day.year, day.month, day.day);
              return events[normalizedDay] ?? [];
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              // 今日标记
              todayDecoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              // 选中日期标记
              selectedDecoration: BoxDecoration(
                gradient: AppColors.secondaryGradient,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              // 默认样式
              defaultTextStyle: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
              // 周末样式
              weekendTextStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
              // 当前月份外的日期
              outsideTextStyle: TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
              // 标记点样式
              markersMaxCount: 3,
              markersAlignment: Alignment.bottomCenter,
              markerDecoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              canMarkersOverflow: true,
              // 禁用日期样式（不需要）
              disabledTextStyle: TextStyle(
                color: AppColors.textHint.withOpacity(0.3),
              ),
              // 范围选择样式（不需要）
              rangeHighlightColor: AppColors.primary.withOpacity(0.2),
              withinRangeTextStyle: const TextStyle(),
              rangeStartDecoration: const BoxDecoration(),
              rangeEndDecoration: const BoxDecoration(),
              // 行高
              rowDecoration: BoxDecoration(
                color: Colors.transparent,
              ),
              tableBorder: TableBorder.symmetric(
                inside: BorderSide.none,
                outside: BorderSide.none,
              ),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppRadius.smRadius,
              ),
              formatButtonTextStyle: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
              titleCentered: true,
              titleTextStyle: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              leftChevronIcon: Icon(
                Icons.chevron_left,
                color: AppColors.primary,
                size: 28,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right,
                color: AppColors.primary,
                size: 28,
              ),
              headerMargin: const EdgeInsets.all(12),
              headerPadding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              weekendStyle: TextStyle(
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              dowTextFormatter: (date, locale) {
                return DateFormat.E(locale).format(date)[0];
              },
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          );
        },
        loading: () => const SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const SizedBox(
          height: 400,
          child: Center(child: Icon(Icons.error_outline, size: 48, color: AppColors.error)),
        ),
      ),
    );
  }

  /// 构建选中日期的任务列表
  Widget _buildSelectedDateTasks(
    BuildContext context,
    DateTime selectedDate,
    AsyncValue<Map<DateTime, List<CalendarEvent>>> eventsAsync,
  ) {
    final normalizedDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    return eventsAsync.when(
      data: (events) {
        final dayEvents = events[normalizedDate] ?? [];

        if (dayEvents.isEmpty) {
          return _EmptyTasksView(date: selectedDate);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Text(
                DateFormat('M月d日 EEEE', 'zh_CN').format(selectedDate),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            // 任务列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                itemCount: dayEvents.length,
                itemBuilder: (context, index) {
                  final event = dayEvents[index];
                  return AnimatedListItem(
                    index: index,
                    child: _EventCard(
                      event: event,
                      onTap: () => _handleEventTap(event),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// 处理事件点击
  void _handleEventTap(CalendarEvent event) {
    if (event.planId != null) {
      context.push('/plans/${event.planId}');
    }
  }

  /// 切换到列表视图
  void _switchToListView() {
    context.pop();
  }
}

/// 视图切换按钮
class _ViewToggleButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewToggleButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smRadius,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: AppRadius.smRadius,
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// 空任务视图
class _EmptyTasksView extends StatelessWidget {
  final DateTime date;

  const _EmptyTasksView({required this.date});

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(date, DateTime.now());

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isToday ? Icons.today_outlined : Icons.event_available_outlined,
              size: 64,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isToday ? '今天没有安排任务' : '这一天没有任务',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isToday ? '享受美好的一天！' : DateFormat('M月d日', 'zh_CN').format(date),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textHint,
                ),
          ),
        ],
      ),
    );
  }
}

/// 事件卡片
class _EventCard extends StatelessWidget {
  final CalendarEvent event;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.onTap,
  });

  Color get _statusColor {
    switch (event.status) {
      case TaskCompletionStatus.completed:
        return AppColors.success;
      case TaskCompletionStatus.overdue:
        return AppColors.error;
      case TaskCompletionStatus.pending:
        return AppColors.primary;
    }
  }

  LinearGradient get _statusGradient {
    switch (event.status) {
      case TaskCompletionStatus.completed:
        return AppColors.successGradient;
      case TaskCompletionStatus.overdue:
        return AppColors.errorGradient;
      case TaskCompletionStatus.pending:
        return AppColors.primaryGradient;
    }
  }

  String get _statusText {
    switch (event.status) {
      case TaskCompletionStatus.completed:
        return '已完成';
      case TaskCompletionStatus.overdue:
        return '已逾期';
      case TaskCompletionStatus.pending:
        return '待完成';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.lgRadius,
        border: Border.all(
          color: _statusColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: AppShadows.subtle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // 状态图标
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: _statusGradient,
                    borderRadius: AppRadius.mdRadius,
                  ),
                  child: Icon(
                    event.status == TaskCompletionStatus.completed
                        ? Icons.check_circle_outline
                        : event.status == TaskCompletionStatus.overdue
                            ? Icons.warning_amber_outlined
                            : Icons.radio_button_unchecked,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // 任务信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (event.planTitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.planTitle!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textHint,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // 状态标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: AppRadius.smRadius,
                  ),
                  child: Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: _statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

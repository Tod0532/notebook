package com.thicknotepad.thick_notepad.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import com.thicknotepad.thick_notepad.MainActivity
import com.thicknotepad.thick_notepad.R

/**
 * 运动打卡小组件 (4x1)
 * 功能：
 * - 显示今日运动记录
 * - 快速打卡按钮
 * - 卡路里统计
 */
class WorkoutWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION_QUICK_CHECKIN = "com.thicknotepad.QUICK_CHECKIN"
        private const val ACTION_OPEN_WORKOUT = "com.thicknotepad.OPEN_WORKOUT"
        private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_WORKOUT"
        private const val PREFS_NAME = "WorkoutWidgetPrefs"
        private const val KEY_CALORIES = "calories"
        private const val KEY_DURATION = "duration"
        private const val KEY_CHECKED_IN = "checked_in"
        private const val KEY_WORKOUT_TYPE = "workout_type"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        // 更新所有小组件实例
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        when (intent.action) {
            ACTION_QUICK_CHECKIN -> {
                // 快速打卡
                val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                prefs.edit().apply {
                    putBoolean(KEY_CHECKED_IN, true)
                    putLong(KEY_CHECKED_IN + "_time", System.currentTimeMillis())
                    apply()
                }

                // 打开应用进行详细记录
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("action", "workout_checkin")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(openIntent)

                // 刷新小组件
                val refreshIntent = Intent(context, WorkoutWidget::class.java).apply {
                    action = ACTION_REFRESH
                }
                context.sendBroadcast(refreshIntent)
            }
            ACTION_OPEN_WORKOUT -> {
                // 打开应用到运动页面
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("action", "view_workout")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(openIntent)
            }
            ACTION_REFRESH -> {
                // 刷新小组件数据
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, WorkoutWidget::class.java)
                )
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    override fun onEnabled(context: Context) {
        // 第一个小组件添加到桌面时调用
    }

    override fun onDisabled(context: Context) {
        // 最后一个小组件从桌面移除时调用
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_workout)

        // 获取存储的数据
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val calories = prefs.getInt(KEY_CALORIES, 0)
        val duration = prefs.getInt(KEY_DURATION, 0)
        val checkedIn = prefs.getBoolean(KEY_CHECKED_IN, false)
        val workoutType = prefs.getString(KEY_WORKOUT_TYPE, "运动") ?: "运动"

        // 设置运动数据
        views.setTextViewText(R.id.caloriesText, "${calories} kcal")
        views.setTextViewText(R.id.durationText, "${duration} min")

        // 设置打卡状态
        if (checkedIn) {
            views.setTextViewText(R.id.checkinStatus, "已打卡")
            views.setBoolean(R.id.checkinBtn, "setEnabled", false)
            views.setTextColor(R.id.checkinStatus, 0xFF4CAF50.toInt())
        } else {
            views.setTextViewText(R.id.checkinStatus, "未打卡")
            views.setBoolean(R.id.checkinBtn, "setEnabled", true)
            views.setTextColor(R.id.checkinStatus, 0xFF9E9E9E.toInt())
        }

        // 设置运动类型
        views.setTextViewText(R.id.workoutType, workoutType)

        // 快速打卡按钮
        val checkinIntent = Intent(context, WorkoutWidget::class.java).apply {
            action = ACTION_QUICK_CHECKIN
        }
        val checkinPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            checkinIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.checkinBtn, checkinPendingIntent)

        // 打开应用查看详细记录
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("action", "view_workout")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            1,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.openAppBtn, openAppPendingIntent)

        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

/**
 * 用于更新小组件数据的工具类
 * Flutter端可以通过MethodChannel调用此方法更新数据
 */
object WorkoutWidgetUpdater {
    fun updateWorkoutData(
        context: Context,
        calories: Int,
        duration: Int,
        workoutType: String = "运动"
    ) {
        val prefs = context.getSharedPreferences("WorkoutWidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putInt("calories", calories)
            putInt("duration", duration)
            putString("workout_type", workoutType)
            apply()
        }

        // 触发小组件刷新
        val intent = Intent(context, WorkoutWidget::class.java).apply {
            action = ACTION_REFRESH
        }
        context.sendBroadcast(intent)
    }

    fun resetDailyCheckin(context: Context) {
        val prefs = context.getSharedPreferences("WorkoutWidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putBoolean("checked_in", false)
            putInt("calories", 0)
            putInt("duration", 0)
            apply()
        }

        // 触发小组件刷新
        val intent = Intent(context, WorkoutWidget::class.java).apply {
            action = ACTION_REFRESH
        }
        context.sendBroadcast(intent)
    }

    private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_WORKOUT"
}

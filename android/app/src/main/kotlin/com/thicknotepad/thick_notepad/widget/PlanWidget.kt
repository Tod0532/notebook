package com.thicknotepad.thick_notepad.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import com.thicknotepad.thick_notepad.MainActivity
import com.thicknotepad.thick_notepad.R

/**
 * 今日计划小组件 (4x2)
 * 功能：
 * - 显示今日任务数
 * - 已完成/总数进度
 * - 快速打开应用
 */
class PlanWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION_OPEN_APP = "com.thicknotepad.OPEN_PLAN_APP"
        private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_PLAN"
        private const val PREFS_NAME = "PlanWidgetPrefs"
        private const val KEY_TOTAL_TASKS = "total_tasks"
        private const val KEY_COMPLETED_TASKS = "completed_tasks"
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
            ACTION_OPEN_APP -> {
                // 打开应用到计划页面
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("action", "view_plan")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(openIntent)
            }
            ACTION_REFRESH -> {
                // 刷新小组件数据
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, PlanWidget::class.java)
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
        val views = RemoteViews(context.packageName, R.layout.widget_plan)

        // 获取存储的数据
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val totalTasks = prefs.getInt(KEY_TOTAL_TASKS, 0)
        val completedTasks = prefs.getInt(KEY_COMPLETED_TASKS, 0)

        // 设置任务数量
        views.setTextViewText(R.id.totalTasks, "$totalTasks")
        views.setTextViewText(R.id.completedTasks, "$completedTasks")

        // 设置进度文本
        val progressText = if (totalTasks > 0) {
            "$completedTasks/$totalTasks"
        } else {
            "0/0"
        }
        views.setTextViewText(R.id.progressText, progressText)

        // 设置进度条
        val progress = if (totalTasks > 0) {
            (completedTasks * 100 / totalTasks)
        } else {
            0
        }
        views.setProgressBar(R.id.progressBar, 100, progress, false)

        // 根据完成度显示不同提示
        val statusText = when {
            totalTasks == 0 -> "今日暂无计划"
            completedTasks == totalTasks -> "今日计划已完成！"
            completedTasks > totalTasks / 2 -> "继续加油！"
            else -> "开始今日任务"
        }
        views.setTextViewText(R.id.statusText, statusText)

        // 整个小组件点击打开应用
        val openAppIntent = Intent(context, PlanWidget::class.java).apply {
            action = ACTION_OPEN_APP
        }
        val openAppPendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.planWidgetContainer, openAppPendingIntent)

        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}

/**
 * 用于更新小组件数据的工具类
 * Flutter端可以通过MethodChannel调用此方法更新数据
 */
object PlanWidgetUpdater {
    fun updatePlanData(context: Context, totalTasks: Int, completedTasks: Int) {
        val prefs = context.getSharedPreferences("PlanWidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putInt("total_tasks", totalTasks)
            putInt("completed_tasks", completedTasks)
            apply()
        }

        // 触发小组件刷新
        val intent = Intent(context, PlanWidget::class.java).apply {
            action = ACTION_REFRESH
        }
        context.sendBroadcast(intent)
    }

    private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_PLAN"
}

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
 * 快速笔记小组件 (4x2)
 * 功能：
 * - 显示笔记数量
 * - 快速创建笔记按钮
 * - 最近笔记预览
 */
class NoteWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION_CREATE_NOTE = "com.thicknotepad.CREATE_NOTE"
        private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_NOTES"
        private const val PREFS_NAME = "NoteWidgetPrefs"
        private const val KEY_NOTE_COUNT = "note_count"
        private const val KEY_RECENT_NOTE = "recent_note"
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
            ACTION_CREATE_NOTE -> {
                // 打开应用并创建新笔记
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    putExtra("action", "create_note")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                context.startActivity(openIntent)
            }
            ACTION_REFRESH -> {
                // 刷新小组件数据
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, NoteWidget::class.java)
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
        val views = RemoteViews(context.packageName, R.layout.widget_note)

        // 获取存储的数据
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val noteCount = prefs.getInt(KEY_NOTE_COUNT, 0)
        val recentNote = prefs.getString(KEY_RECENT_NOTE, "暂无最近笔记") ?: "暂无最近笔记"

        // 设置笔记数量
        views.setTextViewText(R.id.noteCount, "$noteCount")

        // 设置最近笔记预览
        val previewText = if (recentNote.length > 20) {
            recentNote.substring(0, 20) + "..."
        } else {
            recentNote
        }
        views.setTextViewText(R.id.recentNotePreview, previewText)

        // 创建笔记按钮点击事件
        val createNoteIntent = Intent(context, NoteWidget::class.java).apply {
            action = ACTION_CREATE_NOTE
        }
        val createNotePendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            createNoteIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.createNoteBtn, createNotePendingIntent)

        // 打开应用查看所有笔记
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("action", "view_notes")
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
object NoteWidgetUpdater {
    fun updateNoteData(context: Context, noteCount: Int, recentNote: String) {
        val prefs = context.getSharedPreferences("NoteWidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putInt("note_count", noteCount)
            putString("recent_note", recentNote)
            apply()
        }

        // 触发小组件刷新
        val intent = Intent(context, NoteWidget::class.java).apply {
            action = ACTION_REFRESH
        }
        context.sendBroadcast(intent)
    }

    private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_NOTES"
}

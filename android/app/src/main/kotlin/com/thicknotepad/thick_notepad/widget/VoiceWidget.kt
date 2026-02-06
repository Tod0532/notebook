package com.thicknotepad.thick_notepad.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import android.widget.RemoteViews
import com.thicknotepad.thick_notepad.MainActivity
import com.thicknotepad.thick_notepad.R
import java.util.Locale

/**
 * 语音助手小组件 (2x2)
 * 功能：
 * - 麦克风按钮
 * - 快速启动语音识别
 */
class VoiceWidget : AppWidgetProvider() {

    companion object {
        private const val ACTION_START_VOICE = "com.thicknotepad.START_VOICE"
        private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_VOICE"
        private const val PREFS_NAME = "VoiceWidgetPrefs"
        private const val KEY_LAST_RESULT = "last_result"
        private const val KEY_IS_LISTENING = "is_listening"
        private const val VOICE_REQUEST_CODE = 5678
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
            ACTION_START_VOICE -> {
                // 启动语音识别
                startVoiceRecognition(context)
            }
            ACTION_REFRESH -> {
                // 刷新小组件数据
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(
                    ComponentName(context, VoiceWidget::class.java)
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
        val views = RemoteViews(context.packageName, R.layout.widget_voice)

        // 获取存储的数据
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastResult = prefs.getString(KEY_LAST_RESULT, "点击说话") ?: "点击说话"
        val isListening = prefs.getBoolean(KEY_IS_LISTENING, false)

        // 设置最近识别结果
        val displayText = if (lastResult.length > 15) {
            lastResult.substring(0, 15) + "..."
        } else {
            lastResult
        }
        views.setTextViewText(R.id.voiceResult, displayText)

        // 设置麦克风按钮状态
        if (isListening) {
            views.setInt(R.id.micBtn, "setImageResource", R.drawable.ic_mic_listening)
        } else {
            views.setInt(R.id.micBtn, "setImageResource", R.drawable.ic_mic)
        }

        // 麦克风按钮点击事件
        val voiceIntent = Intent(context, VoiceWidget::class.java).apply {
            action = ACTION_START_VOICE
        }
        val voicePendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            voiceIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.micBtn, voicePendingIntent)

        // 点击结果打开应用
        val openAppIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("action", "view_voice_result")
            putExtra("result", lastResult)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            1,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        views.setOnClickPendingIntent(R.id.voiceResult, openAppPendingIntent)

        // 更新小组件
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /**
     * 启动语音识别
     */
    private fun startVoiceRecognition(context: Context) {
        // 更新状态为正在监听
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_IS_LISTENING, true).apply()

        val refreshIntent = Intent(context, VoiceWidget::class.java).apply {
            action = ACTION_REFRESH
        }
        context.sendBroadcast(refreshIntent)

        // 检查语音识别是否可用
        val pm = context.packageManager
        val activities = pm.queryIntentActivities(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH), 0
        )

        if (activities.isEmpty()) {
            // 语音识别不可用，打开应用提示用户
            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra("action", "voice_not_available")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(openIntent)

            prefs.edit().putBoolean(KEY_IS_LISTENING, false).apply()
            return
        }

        // 创建一个空Activity用于接收语音识别结果
        val voiceIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.CHINA)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "正在听您说...")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // 使用FLAG_ACTIVITY_NEW_TASK确保从小组件启动
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        try {
            context.startActivity(voiceIntent)

            // 延迟重置状态（假设用户会在一段时间内完成语音输入）
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                prefs.edit().putBoolean(KEY_IS_LISTENING, false).apply()
                val resetIntent = Intent(context, VoiceWidget::class.java).apply {
                    action = ACTION_REFRESH
                }
                context.sendBroadcast(resetIntent)
            }, 5000)
        } catch (e: Exception) {
            // 启动失败，打开应用
            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                putExtra("action", "start_voice")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(openIntent)

            prefs.edit().putBoolean(KEY_IS_LISTENING, false).apply()
        }
    }
}

/**
 * 用于更新小组件数据的工具类
 * Flutter端可以通过MethodChannel调用此方法更新数据
 */
object VoiceWidgetUpdater {
    fun updateVoiceResult(context: Context, result: String) {
        val prefs = context.getSharedPreferences("VoiceWidgetPrefs", Context.MODE_PRIVATE)
        prefs.edit().apply {
            putString("last_result", result)
            putBoolean("is_listening", false)
            apply()
        }

        // 触发小组件刷新
        val intent = Intent(context, VoiceWidget::class.java).apply {
            action = ACTION_REFRESH
        }
        context.sendBroadcast(intent)
    }

    private const val ACTION_REFRESH = "com.thicknotepad.REFRESH_VOICE"
}

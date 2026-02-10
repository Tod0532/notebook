package com.thicknotepad.thick_notepad

import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.thicknotepad.thick_notepad.widget.NoteWidgetUpdater
import com.thicknotepad.thick_notepad.widget.PlanWidgetUpdater
import com.thicknotepad.thick_notepad.widget.WorkoutWidgetUpdater
import com.thicknotepad.thick_notepad.widget.VoiceWidgetUpdater

/**
 * MainActivity - 支持原生语音识别、桌面小组件和通知
 *
 * 通知说明：
 * - flutter_local_notifications v17+ 使用内部接收器处理通知
 * - 设备重启后通知会通过 ScheduledNotificationBootReceiver 自动恢复
 */
class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val SPEECH_CHANNEL = "com.thicknotepad.thick_notepad/speech"
    private val WIDGET_CHANNEL = "com.thicknotepad.thick_notepad/widget"
    private val NOTIFICATION_CHANNEL = "com.thicknotepad.thick_notepad/notification"
    private val SPEECH_REQUEST_CODE = 1234

    private var speechChannel: MethodChannel? = null
    private var widgetChannel: MethodChannel? = null
    private var notificationChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 通知通道
        notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        notificationChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "debugPrint" -> {
                    val message = call.argument<String>("message")
                    Log.d(TAG, "Flutter: $message")
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 语音识别通道
        speechChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        speechChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startSpeechRecognition" -> {
                    val language = call.argument<String>("language")
                    startSpeechRecognition(language, result)
                }
                "checkSpeechRecognitionAvailable" -> {
                    checkSpeechRecognitionAvailable(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // 桌面小组件通道
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
        widgetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateNoteWidget" -> {
                    val noteCount = call.argument<Int>("noteCount") ?: 0
                    val recentNote = call.argument<String>("recentNote") ?: ""
                    NoteWidgetUpdater.updateNoteData(this, noteCount, recentNote)
                    result.success(null)
                }
                "updatePlanWidget" -> {
                    val totalTasks = call.argument<Int>("totalTasks") ?: 0
                    val completedTasks = call.argument<Int>("completedTasks") ?: 0
                    PlanWidgetUpdater.updatePlanData(this, totalTasks, completedTasks)
                    result.success(null)
                }
                "updateWorkoutWidget" -> {
                    val calories = call.argument<Int>("calories") ?: 0
                    val duration = call.argument<Int>("duration") ?: 0
                    val workoutType = call.argument<String>("workoutType") ?: "运动"
                    WorkoutWidgetUpdater.updateWorkoutData(this, calories, duration, workoutType)
                    result.success(null)
                }
                "resetWorkoutCheckin" -> {
                    WorkoutWidgetUpdater.resetDailyCheckin(this)
                    result.success(null)
                }
                "updateVoiceResult" -> {
                    val voiceResult = call.argument<String>("result") ?: ""
                    VoiceWidgetUpdater.updateVoiceResult(this, voiceResult)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * 启动原生语音识别
     */
    private fun startSpeechRecognition(language: String?, result: MethodChannel.Result) {
        Log.d(TAG, "启动语音识别，语言: $language")

        val pm = packageManager
        val activities = pm.queryIntentActivities(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH), 0
        )

        if (activities.isEmpty()) {
            Log.e(TAG, "没有可用的语音识别服务")
            result.error(
                "NO_SPEECH_SERVICE",
                "设备没有可用的语音识别服务。请检查输入设置中是否启用了语音输入。",
                null
            )
            return
        }

        Log.d(TAG, "找到 ${activities.size} 个语音识别服务")

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, language ?: "zh-CN")
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PROMPT, "正在听您说...")
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
        }

        pendingResult = result

        try {
            startActivityForResult(intent, SPEECH_REQUEST_CODE)
        } catch (e: Exception) {
            Log.e(TAG, "启动语音识别失败", e)
            result.error(
                "START_FAILED",
                "启动语音识别失败: ${e.message}",
                null
            )
            pendingResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == SPEECH_REQUEST_CODE) {
            Log.d(TAG, "语音识别结果: resultCode=$resultCode")

            when (resultCode) {
                RESULT_OK -> {
                    val matches = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                    Log.d(TAG, "识别到 ${matches?.size} 个结果")

                    if (!matches.isNullOrEmpty()) {
                        val recognizedText = matches[0]
                        Log.d(TAG, "识别结果: $recognizedText")

                        pendingResult?.success(mapOf(
                            "text" to recognizedText,
                            "isFinal" to true,
                            "alternatives" to matches.toList()
                        ))
                    } else {
                        pendingResult?.error(
                            "NO_RESULTS",
                            "没有识别到语音内容。请说话更清晰或靠近麦克风。",
                            null
                        )
                    }
                }
                RESULT_CANCELED -> {
                    Log.d(TAG, "用户取消了语音识别")
                    pendingResult?.error(
                        "CANCELED",
                        "用户取消",
                        null
                    )
                }
                else -> {
                    Log.e(TAG, "语音识别失败，代码: $resultCode")
                    pendingResult?.error(
                        "RECOGNITION_ERROR",
                        "语音识别失败。请确保设备支持语音识别功能。",
                        null
                    )
                }
            }

            pendingResult = null
        }
    }

    private fun checkSpeechRecognitionAvailable(result: MethodChannel.Result) {
        val pm = packageManager
        val activities = pm.queryIntentActivities(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH), 0
        )

        val isAvailable = activities.isNotEmpty()
        Log.d(TAG, "语音识别可用: $isAvailable, 服务数量: ${activities.size}")

        result.success(mapOf(
            "available" to isAvailable,
            "serviceCount" to activities.size
        ))
    }

    override fun onDestroy() {
        super.onDestroy()
        speechChannel?.setMethodCallHandler(null)
        speechChannel = null
        widgetChannel?.setMethodCallHandler(null)
        widgetChannel = null
        notificationChannel?.setMethodCallHandler(null)
        notificationChannel = null
        pendingResult = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 处理从小组件启动的Intent
        handleWidgetIntent(intent)

        // 处理从通知启动的Intent
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleWidgetIntent(intent)
        handleNotificationIntent(intent)
    }

    /**
     * 处理来自通知的Intent
     */
    private fun handleNotificationIntent(intent: Intent?) {
        Log.d(TAG, "handleNotificationIntent: ${intent?.action}")

        // 检查是否从通知启动
        val extras = intent?.extras
        if (extras != null) {
            // 检查 flutter_local_notifications 的 payload
            if (extras.containsKey("notification_id")) {
                val notificationId = extras.getInt("notification_id")
                val payload = extras.getString("payload")
                Log.d(TAG, "通知点击: id=$notificationId, payload=$payload")

                // 通知 Flutter 处理通知点击
                notificationChannel?.invokeMethod("onNotificationTap", mapOf(
                    "id" to notificationId,
                    "payload" to (payload ?: "")
                ))
            }
        }
    }

    /**
     * 处理来自小组件的Intent
     */
    private fun handleWidgetIntent(intent: Intent?) {
        intent?.getStringExtra("action")?.let { action ->
            Log.d(TAG, "收到小组件操作: $action")

            // 通知Flutter处理小组件操作
            widgetChannel?.invokeMethod("onWidgetAction", mapOf(
                "action" to action,
                "data" to intent.extras?.get("result")
            ))
        }
    }
}

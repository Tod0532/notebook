package com.thicknotepad.thick_notepad

import android.content.Intent
import android.os.Bundle
import android.speech.RecognizerIntent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MainActivity - 支持原生语音识别
 */
class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val SPEECH_CHANNEL = "com.thicknotepad.thick_notepad/speech"
    private val SPEECH_REQUEST_CODE = 1234

    private var methodChannel: MethodChannel? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SPEECH_CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
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
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        pendingResult = null
    }
}

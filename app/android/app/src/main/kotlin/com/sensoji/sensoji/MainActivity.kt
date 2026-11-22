package com.sensoji.sensoji

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 搖籤與落籤的震動：直接驅動馬達，可調長度與強度（lib/logic/haptics.dart）。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sensoji/haptics")
            .setMethodCallHandler { call, result ->
                if (call.method != "pulse") return@setMethodCallHandler result.notImplemented()
                val ms = (call.argument<Int>("ms") ?: 60).toLong()
                val amplitude = (call.argument<Int>("amplitude") ?: 255).coerceIn(1, 255)
                val v = vibrator()
                if (v == null || !v.hasVibrator()) return@setMethodCallHandler result.success(null)
                if (Build.VERSION.SDK_INT >= 26) {
                    val amp = if (v.hasAmplitudeControl()) amplitude else VibrationEffect.DEFAULT_AMPLITUDE
                    v.vibrate(VibrationEffect.createOneShot(ms, amp))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(ms)
                }
                result.success(null)
            }
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= 31) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
}

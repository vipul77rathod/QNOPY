package com.example.qnopy

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "app/screenshot"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {
                "enableScreenshotProtection" -> {
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                    result.success(true)
                }

                "disableScreenshotProtection" -> {
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_SECURE
                    )
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
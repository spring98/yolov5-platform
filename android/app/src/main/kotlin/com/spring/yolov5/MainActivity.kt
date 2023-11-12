@file:Suppress("PrivatePropertyName")

package com.spring.yolov5

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


@androidx.camera.core.ExperimentalGetImage
class MainActivity: FlutterActivity() {
    private val CHANNEL = "camera_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.dartExecutor.binaryMessenger.let {
            MethodChannel(it, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "triggerCamera") {
                    flutterEngine
                        .platformViewsController
                        .registry
                        .registerViewFactory(
                            "camera_view", NativeCameraViewFactory(this@MainActivity, it)
                        )

                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

}

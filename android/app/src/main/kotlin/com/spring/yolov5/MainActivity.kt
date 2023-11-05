@file:Suppress("PrivatePropertyName")

package com.spring.yolov5

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel


@androidx.camera.core.ExperimentalGetImage
class MainActivity: FlutterActivity() {
    private val CHANNEL = "camera_channel"
    private val CAMERA_ACTIVITY_REQUEST_CODE = 12345

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

//        flutterEngine?.dartExecutor?.binaryMessenger?.let {
//            MethodChannel(it, CHANNEL).setMethodCallHandler { call, result ->
//                if (call.method == "triggerCamera") {
////                    val intent = Intent(this, CameraActivity::class.java)
////                    startActivityForResult(intent, CAMERA_ACTIVITY_REQUEST_CODE)
//
//
//                    result.success(null)
//                } else {
//                    result.notImplemented()
//                }
//            }
//        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine
            .platformViewsController
            .registry
            .registerViewFactory(
                "camera_view", NativeCameraViewFactory(flutterEngine.dartExecutor.binaryMessenger, this@MainActivity)
            )

        flutterEngine.dartExecutor.binaryMessenger.let {
            MethodChannel(it, CHANNEL).setMethodCallHandler { call, result ->
                if (call.method == "triggerCamera") {
//                    val intent = Intent(this, CameraActivity::class.java)
//                    startActivityForResult(intent, CAMERA_ACTIVITY_REQUEST_CODE)

                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

//        if (requestCode == CAMERA_ACTIVITY_REQUEST_CODE) {
//            // Handle the result from CameraActivity
//        }
    }
}

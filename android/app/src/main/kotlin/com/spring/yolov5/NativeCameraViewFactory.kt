package com.spring.yolov5

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import android.util.Log
import android.view.View
import androidx.annotation.RequiresApi
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NativeCameraViewFactory(private val messenger: BinaryMessenger, private val activity: MainActivity) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeCameraView(context, messenger, viewId, activity)
    }
}

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
class NativeCameraView(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val viewId: Int,
    private val activity: MainActivity
) : PlatformView {
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private val previewView = PreviewView(context)

    init {
        setupCamera()
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    private fun setupCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener(Runnable{
            val cameraProvider = cameraProviderFuture.get()

//            val activity = context.getActivity()
//            if (activity == null) {
//                Log.e("NativeCameraView", "Unable to get AppCompatActivity from context.")
//                return@Runnable
//            }

            // Create a Preview
            val preview = Preview.Builder().build()

            // Select the back camera
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            // Unbind any bound use cases before rebinding
            cameraProvider.unbindAll()

            // Bind the Preview use case to the camera provider
            try {
                cameraProvider.bindToLifecycle(
//                    context as AppCompatActivity,
                    activity,
                    cameraSelector,
                    preview
                )

                // Connect the preview use case to the preview view
                preview.setSurfaceProvider(previewView.surfaceProvider)
            } catch (e: Exception) {
                // Handle any errors (including a failed binding)
                e.printStackTrace()
            }

        }, ContextCompat.getMainExecutor(context))
    }

    fun Context.getActivity(): AppCompatActivity? {
        var context = this
        while (context is ContextWrapper) {
            if (context is AppCompatActivity) {
                return context
            }
            context = context.baseContext
        }
        return null
    }


    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun getView(): View {
        return previewView
    }

    override fun dispose() {}
}
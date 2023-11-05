package com.spring.yolov5

import android.Manifest
import android.content.pm.PackageManager
import android.media.Image
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity

@androidx.camera.core.ExperimentalGetImage
class CameraActivity : FlutterActivity() {

    private lateinit var viewFinder: PreviewView

    @RequiresApi(Build.VERSION_CODES.M)
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContentView(R.layout.activity_camera)
        viewFinder = findViewById(R.id.viewFinder)

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == PackageManager.PERMISSION_GRANTED
        ) {
            startCamera()
        } else {
            requestPermissions(arrayOf(Manifest.permission.CAMERA), 1234)
        }
    }

    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener(Runnable {
            val cameraProvider = cameraProviderFuture.get()
//            val preview = Preview.Builder().build()
            val preview = Preview.Builder().build().also {
                it.setSurfaceProvider(viewFinder.surfaceProvider)
            }

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            val imageAnalysis = ImageAnalysis.Builder().build().also {
                it.setAnalyzer(ContextCompat.getMainExecutor(this), ImageAnalyzer { image ->
//                    sendImageDataToFlutter(image)
                })
            }

            try {
                cameraProvider.unbindAll()
                cameraProvider.bindToLifecycle(this, cameraSelector, preview, imageAnalysis)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }, ContextCompat.getMainExecutor(this))
    }
}

@androidx.camera.core.ExperimentalGetImage
class ImageAnalyzer(private val listener: (Image) -> Unit) : ImageAnalysis.Analyzer {
    @RequiresApi(Build.VERSION_CODES.LOLLIPOP)
    override fun analyze(image: ImageProxy) {
        listener(image.image!!)
        image.close()
    }
}

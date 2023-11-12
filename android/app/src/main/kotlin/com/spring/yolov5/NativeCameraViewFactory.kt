@file:Suppress("PrivatePropertyName", "UNUSED_VARIABLE", "LocalVariableName")

package com.spring.yolov5

import android.content.Context
import android.graphics.*
import android.util.Log
import android.view.View
import androidx.annotation.OptIn
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import com.spring.yolov5.Constants.Companion.CLASS_LABELS
import com.spring.yolov5.Constants.Companion.CONFIDENCE_THRESHOLD
import com.spring.yolov5.Constants.Companion.DETECTION_SIZE
import com.spring.yolov5.Constants.Companion.IOU_THRESHOLD
import com.spring.yolov5.Constants.Companion.MODEL_SIZE
import com.spring.yolov5.Constants.Companion.PADDING_SIZE
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import org.pytorch.IValue
import org.pytorch.Module
import org.pytorch.PyTorchAndroid
import org.pytorch.torchvision.TensorImageUtils
import java.util.concurrent.Executors

class NativeCameraViewFactory(private val activity: MainActivity, private val message: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return NativeCameraView(context, activity, message)
    }
}

class NativeCameraView(
    private val context: Context,
    private val activity: MainActivity,
    private val message: BinaryMessenger
) : PlatformView {

    private val previewView = PreviewView(context)
    private var model: Module
    private var NO_MEAN_RGB = floatArrayOf(0.0f, 0.0f, 0.0f)
    private var NO_STD_RGB = floatArrayOf(1.0f, 1.0f, 1.0f)

    init {
        model = PyTorchAndroid.loadModuleFromAsset(
            activity.assets,
            "yolov5s_320.pt"
        )
        setupCamera()
    }

    override fun dispose() {}

    private fun setupCamera() {
        previewView.scaleType = PreviewView.ScaleType.FILL_CENTER
        previewView.implementationMode = PreviewView.ImplementationMode.COMPATIBLE

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            // Create a Preview
            val preview = Preview.Builder()
                .build()

            // 단일 스레드 사용
            val executor = Executors.newSingleThreadExecutor()
            // 고정된 스레드 풀 사용
            // val executor = Executors.newFixedThreadPool(Runtime.getRuntime().availableProcessors())

            val imageAnalyzer = ImageAnalysis.Builder()
                .build()
                .also {
                    it.setAnalyzer(executor, Yolov5ImageAnalyzer())
                }

            // Select the back camera
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            // Unbind any bound use cases before rebinding
            cameraProvider.unbindAll()
            // Bind the Preview use case to the camera provider
            try {
                cameraProvider.bindToLifecycle(
                    activity,
                    cameraSelector,
                    preview,
                    imageAnalyzer
                )

                // Connect the preview use case to the preview view
                preview.setSurfaceProvider(previewView.surfaceProvider)

                // 카메라가 성공적으로 열렸음을 나타내는 로그
                Log.d("CameraLog", "카메라가 성공적으로 열렸습니다.")

            } catch (exc: Exception) {
                Log.e("CameraLog", "카메라 사용 중 오류 발생: ${exc.localizedMessage}")
            }
        }, ContextCompat.getMainExecutor(context))

    }

    override fun getView(): View {
        return previewView
    }

    private inner class Yolov5ImageAnalyzer : ImageAnalysis.Analyzer {
        @OptIn(ExperimentalGetImage::class)
        override fun analyze(image: ImageProxy) {

            // 이미지를 Bitmap 으로 변환
            var bitmap = image.toBitmap()

            // 640 * 480
            bitmap =
                Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, Matrix(), true)

            // 320 * 240
            val resize320_240 =
                Bitmap.createScaledBitmap(bitmap, MODEL_SIZE, MODEL_SIZE - 2*PADDING_SIZE, true)

            // 320 * 320
            val zeroPadding320_320 =
                resize320_240.addPadding(Color.BLACK, 0, PADDING_SIZE, 0, PADDING_SIZE)

            // Bitmap To Tensor
            val inputTensor = TensorImageUtils.bitmapToFloat32Tensor(
                zeroPadding320_320,
                NO_MEAN_RGB,
                NO_STD_RGB
            )

            // Tensor -> FloatArray
            val outputTensor = model.forward(IValue.from(inputTensor)).toTuple()[0].toTensor().dataAsFloatArray

            // 결과 처리 (예: 객체 위치, 신뢰도 등)
            val detectionResults = processOutput(outputTensor)

            val nmsDetectionResults = nms(detectionResults, IOU_THRESHOLD)

            // 추론 결과에 따라 필요한 작업 수행
            sendToFlutter(nmsDetectionResults) // Flutter로 결과 전송

            // 이미지 리소스 해제
            image.close()
        }

        private fun Bitmap.addPadding(
            color: Int = Color.BLACK,
            left: Int = 0,
            top: Int = 0,
            right: Int = 0,
            bottom: Int = 0
        ): Bitmap {
            val bitmap = Bitmap.createBitmap(
                width + left + right, // width in pixels
                height + top + bottom, // height in pixels
                Bitmap.Config.ARGB_8888
            )
            val canvas = Canvas(bitmap)
            canvas.drawColor(color)
            Paint().apply {
                xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
                canvas.drawRect(
                    Rect(left, top, bitmap.width - right, bitmap.height - bottom),
                    this
                )
            }
            Paint().apply {
                canvas.drawBitmap(
                    this@addPadding, // bitmap
                    0f + left, // left
                    0f + top, // top
                    this // paint
                )
            }
            return bitmap
        }

        private fun processOutput(tensor: FloatArray): List<DetectionResult> {
            val results = mutableListOf<DetectionResult>()

            // tensor.size = 535500 / 85 = 6300
            for (i in tensor.indices step DETECTION_SIZE) {
                val confidence = tensor[i + 4]
                if (confidence > CONFIDENCE_THRESHOLD) {
                    val x: Float = tensor[i]
                    val y: Float = convertRange(tensor[i + 1])
                    val w: Float = tensor[i + 2]
                    val h: Float = tensor[i + 3] * (MODEL_SIZE + 2*PADDING_SIZE).toFloat()/(MODEL_SIZE - 2*PADDING_SIZE)

                    val left = (x - w / 2) / MODEL_SIZE
                    val top = ((MODEL_SIZE - y - h / 2) / MODEL_SIZE)
                    val width = w / MODEL_SIZE
                    val height = (h / MODEL_SIZE)

                    var maxClassScore = tensor[i + 5]
                    var cls = 0
                    for (j in 0 until DETECTION_SIZE - 5) {
                        if (tensor[i + 5 + j] > maxClassScore) {
                            maxClassScore = tensor[i + 5 + j]
                            cls = j
                        }
                    }

                    val rect = RectLTWH(left, top, width, height)
                    results.add(DetectionResult(rect, getClassLabel(cls), confidence))
                }
            }

            return results
        }

        fun convertRange(originalValue: Float): Float {
            val originalMin = PADDING_SIZE.toFloat()
            val originalMax = MODEL_SIZE.toFloat() - PADDING_SIZE.toFloat()
            val newMin = - PADDING_SIZE.toFloat()
            val newMax = MODEL_SIZE.toFloat() + PADDING_SIZE.toFloat()

            return ((originalValue - originalMin) / (originalMax - originalMin)) * (newMax - newMin) + newMin
        }

        // 클래스 라벨을 얻는 함수 (클래스 인덱스를 클래스 이름으로 변환)
        private fun getClassLabel(classIndex: Int): String {
            return CLASS_LABELS[classIndex]
        }

        private fun sendToFlutter(results: List<DetectionResult>) {
            activity.runOnUiThread {
                val channel = MethodChannel(message, "camera_channel")
                val outerMap = results.mapIndexed { index, result ->
                    "box$index" to mapOf(
                        "x" to result.boundingBox.left,
                        "y" to result.boundingBox.top,
                        "width" to result.boundingBox.width,
                        "height" to result.boundingBox.height,
                        "label" to result.label,
                        "confidence" to result.confidence
                    )
                }.toMap()
                channel.invokeMethod("receiveCameraData", outerMap)
            }
        }
    }

    fun nms(boxes: List<DetectionResult>, iouThreshold: Float): List<DetectionResult> {
        if (boxes.isEmpty()) return emptyList()

        val sortedBoxes = boxes.sortedByDescending { it.confidence }
        val selectedBoxes = mutableListOf<DetectionResult>()

        for (box in sortedBoxes) {
            var shouldSelect = true
            for (selectedBox in selectedBoxes) {
                if (iou(box.boundingBox.toRectF(), selectedBox.boundingBox.toRectF()) > iouThreshold) {
                    shouldSelect = false
                    break
                }
            }
            if (shouldSelect) {
                selectedBoxes.add(box)
            }
        }

        return selectedBoxes
    }

    private fun iou(boxA: RectF, boxB: RectF): Float {
        val intersectionArea = (boxA.right.coerceAtMost(boxB.right) - boxA.left.coerceAtLeast(boxB.left)).coerceAtLeast(0f) *
                (boxA.bottom.coerceAtMost(boxB.bottom) - boxA.top.coerceAtLeast(boxB.top)).coerceAtLeast(0f)

        val boxAArea = (boxA.right - boxA.left) * (boxA.bottom - boxA.top)
        val boxBArea = (boxB.right - boxB.left) * (boxB.bottom - boxB.top)

        val unionArea = boxAArea + boxBArea - intersectionArea

        return if (unionArea > 0f) intersectionArea / unionArea else 0f
    }

    // RectLTWH 클래스의 확장 함수로 RectF 변환
    private fun RectLTWH.toRectF(): RectF {
        return RectF(left, top, left + width, top + height)
    }


}

data class DetectionResult(
    val boundingBox: RectLTWH,  // 객체의 위치 및 크기를 나타내는 경계 상자
    val label: String,       // 객체의 클래스 라벨
    val confidence: Float    // 객체 감지에 대한 신뢰도
)

class RectLTWH (
    left:Float,
    top:Float,
    width:Float,
    height:Float,
) {
    val left = left.coerceIn(0.0f, 1.0f)
    val top = top.coerceIn(0.0f, 1.0f)
    private val right = (left + width).coerceIn(0.0f, 1.0f)
    private val bottom = (top + height).coerceIn(0.0f, 1.0f)
    val width = right - this.left
    val height = bottom - this.top
}


class Constants {
    // 상수 정의
    companion object {
        const val DETECTION_SIZE = 85 // 각 탐지에 대한 정보 개수 (x, y, width, height, confidence, 클래스 신뢰도)
        const val CONFIDENCE_THRESHOLD = 0.5f // 신뢰도 임계값
        const val IOU_THRESHOLD = 0.5f // 신뢰도 임계값
        const val MODEL_SIZE:Int = 320
        const val PADDING_SIZE:Int = 40
        val CLASS_LABELS = arrayOf(
            "person", "bicycle", "car", "motorcycle", "airplane",
            "bus", "train", "truck", "boat", "traffic light",
            "fire hydrant", "stop sign", "parking meter", "bench", "bird",
            "cat", "dog", "horse", "sheep", "cow",
            "elephant", "bear", "zebra", "giraffe", "backpack",
            "umbrella", "handbag", "tie", "suitcase", "frisbee",
            "skis", "snowboard", "sports ball", "kite", "baseball bat",
            "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle",
            "wine glass", "cup", "fork", "knife", "spoon",
            "bowl", "banana", "apple", "sandwich", "orange",
            "broccoli", "carrot", "hot dog", "pizza", "donut",
            "cake", "chair", "couch", "potted plant", "bed",
            "dining table", "toilet", "tv", "laptop", "mouse",
            "remote", "keyboard", "cell phone", "microwave", "oven",
            "toaster", "sink", "refrigerator", "book", "clock",
            "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
        )
    }

}


// Swift side (CameraViewController.swift)
import UIKit
import AVFoundation
import CoreML
import Vision
import CoreImage
import VideoToolbox

class CameraViewController: UIViewController {
    var captureSession: AVCaptureSession!
    var videoDataOutput: AVCaptureVideoDataOutput!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.hidesBackButton = true

        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .hd1920x1080
//        captureSession.sessionPreset = .hd4K3840x2160

        guard let videoDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill  // Set videoGravity to .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if (captureSession.canAddOutput(videoDataOutput)) {
           captureSession.addOutput(videoDataOutput)
        }

        captureSession.startRunning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
    
    
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
//        // Convert CMSampleBuffer to a suitable format
//        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//
//        // Lock the base address of the pixel buffer
//        CVPixelBufferLockBaseAddress(imageBuffer, [])
//
//        // Get the base address and data size of the pixel buffer
//        guard let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) else {
//            CVPixelBufferUnlockBaseAddress(imageBuffer, [])
//            return
//        }
//
//        let dataSize = CVPixelBufferGetDataSize(imageBuffer)
//
//        // Copy the data to a Data object
//        let data = Data(bytes: baseAddress, count: dataSize)
//
//        // Unlock the base address of the pixel buffer
//        CVPixelBufferUnlockBaseAddress(imageBuffer, [])
//
//        // Convert Data to [UInt8]
//        let uint8Buffer = [UInt8](data)
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to convert CMSampleBuffer to CVPixelBuffer")
            return
        }
        
        detect(image: pixelBuffer)
    }
}

// MARK: - CoreML 이미지 분류
extension CameraViewController {
    
    // CoreML의 CIImage를 처리하고 해석하기 위한 메서드 생성, 이것은 모델의 이미지를 분류하기 위해 사용 됩니다.
    func detect(image: CVPixelBuffer) {
        // CoreML의 모델인 FlowerClassifier를 객체를 생성 후,
        // Vision 프레임워크인 VNCoreMLModel 컨터이너를 사용하여 CoreML의 model에 접근한다.

        guard let coreMLModel = try? YOLOv3TinyInt8LUT(configuration: MLModelConfiguration()),
              let visionModel = try? VNCoreMLModel(for: coreMLModel.model) else {
            fatalError("Loading CoreML Model Failed")
        }
        
        
        // 이미치 처리를 요청
        let request = VNCoreMLRequest(model: visionModel) { [self] request, error in
            guard error == nil else {
                fatalError("Failed Request")
            }

            guard let observations = request.results as? [VNRecognizedObjectObservation] else {
                fatalError("Faild convert VNClassificationObservation")
            }
                        
            parseObservations(observations)
        }
        
        // 이미지를 받아와서 perform을 요청하여 분석한다.
        let handler = VNImageRequestHandler(cvPixelBuffer: image)
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
    }
   
    // observations는 VNRecognizedObjectObservation 객체의 배열입니다.
    func parseObservations(_ observations: [VNRecognizedObjectObservation]) {
        for observation in observations {
//            // 신뢰도 점수를 출력합니다.
//            print("Confidence: \(observation.confidence)")
//
//            // bounding box 좌표를 출력합니다.
            let boundingBox = observation.boundingBox
//            print("Bounding Box: \(boundingBox)")
            // Convert the boundingBox to a dictionary
            let boundingBoxDict: [String: Any] = [
                "x": boundingBox.origin.x,
                "y": boundingBox.origin.y,
                "width": boundingBox.size.width,
                "height": boundingBox.size.height,
//                "label": observation.labels.first,
//                "confidence": observation.confidence,
            ]
            
//            // 가능한 레이블을 출력합니다.
//            let labels = observation.labels.map { $0.identifier }.joined(separator: ", ")
//            print("Labels: \(labels)")
//
//            print("-----")  // 각 관찰 사이에 구분선을 출력합니다.
            
            
            // Send data to Flutter
            guard let flutterViewController = flutterViewController else { return }
            let channel = FlutterMethodChannel(name: "camera_channel", binaryMessenger: flutterViewController.binaryMessenger)
            channel.invokeMethod("receiveCameraData", arguments: boundingBoxDict)
        }
    }

}

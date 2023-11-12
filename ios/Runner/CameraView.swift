//
//  CameraView.swift
//  Runner
//
//  Created by spring-dorosee on 2023/11/05.
//

import Foundation
import UIKit
import Flutter
import AVFoundation
import CoreML
import Vision
import CoreImage
import VideoToolbox

class CameraViewFactory: NSObject, FlutterPlatformViewFactory {
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return CameraViewContainer(frame: frame, viewId: viewId)
    }
}

class CameraViewContainer: NSObject, FlutterPlatformView {
    let frame: CGRect
    let viewId: Int64
    let cameraView: CameraView
    
    init(frame: CGRect, viewId: Int64) {
       self.frame = frame
       self.viewId = viewId
       self.cameraView = CameraView(frame: frame)
       super.init()
    }
    
    func view() -> UIView {
        return cameraView
    }
}

class CameraView: UIView {
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    // Add this initializer
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCamera()
    }

    required init?(coder: NSCoder) {
       super.init(coder: coder)
       setupCamera()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer?.frame = self.bounds
        
        print("layoutSubviews called, videoPreviewLayer frame updated: \(videoPreviewLayer?.frame ?? CGRect.zero)")

    }

    func setupCamera() {
       // Create a session
       captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .hd1920x1080
       
       // Get video capture device
       guard let videoDevice = AVCaptureDevice.default(for: .video) else {
           print("Failed to get video device")
           return
       }
       
       // Create input
       var videoInput: AVCaptureDeviceInput!
       do {
           videoInput = try AVCaptureDeviceInput(device: videoDevice)
       } catch {
           print("Failed to create video input: \(error)")
           return
       }
       
       // Add input to session
       if (captureSession?.canAddInput(videoInput) == true) {
           captureSession?.addInput(videoInput)
       } else {
           print("Failed to add video input to session")
           return
       }
       
       // Create video data output
       let videoOutput = AVCaptureVideoDataOutput()
       videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
       
       // Add output to session
       if (captureSession?.canAddOutput(videoOutput) == true) {
           captureSession?.addOutput(videoOutput)
       } else {
           print("Failed to add video output to session")
           return
       }
       
       // Create preview layer
       videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
       videoPreviewLayer?.videoGravity = .resizeAspectFill
       videoPreviewLayer?.frame = self.layer.bounds
        print("Video preview layer frame updated: \(self.bounds)")  // Add debug log

        
       // Add preview layer to view
       self.layer.addSublayer(videoPreviewLayer!)
       
       // Start session
        print("Before starting camera session, videoPreviewLayer frame: \(videoPreviewLayer?.frame ?? CGRect.zero)")
         captureSession?.startRunning()
         print("After starting camera session, videoPreviewLayer frame: \(videoPreviewLayer?.frame ?? CGRect.zero)")
    }

    // Stop camera session when view is removed
    override func removeFromSuperview() {
       super.removeFromSuperview()
       captureSession?.stopRunning()
    }
}

extension CameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to convert CMSampleBuffer to CVPixelBuffer")
            return
        }
        
//        let width = CVPixelBufferGetWidth(pixelBuffer)
//        let height = CVPixelBufferGetHeight(pixelBuffer)
//        print("Input image dimensions: \(width) x \(height)")
        
        detect(image: pixelBuffer)
    }
}

// MARK: - CoreML 이미지 분류
extension CameraView {
    
    // CoreML의 CIImage를 처리하고 해석하기 위한 메서드 생성, 이것은 모델의 이미지를 분류하기 위해 사용 됩니다.
    func detect(image: CVPixelBuffer) {
        // CoreML의 모델인 FlowerClassifier를 객체를 생성 후,
        // Vision 프레임워크인 VNCoreMLModel 컨터이너를 사용하여 CoreML의 model에 접근한다.

        guard let coreMLModel = try? drone_20231110(configuration: MLModelConfiguration()),
//        guard let coreMLModel = try? yolov5s(configuration: MLModelConfiguration()),
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
    
    func parseObservations(_ observations: [VNRecognizedObjectObservation]) {
        var outerMap: [String: [String: Any]] = [:]  // 외부 맵 생성

        for (index, observation) in observations.enumerated() {
            // bounding box 좌표를 얻습니다.
            let boundingBox = observation.boundingBox

            // 내부 맵을 생성합니다.
            let innerMap: [String: Any] = [
                "x": boundingBox.origin.x,
                "y": boundingBox.origin.y,
                "width": boundingBox.size.width,
                "height": boundingBox.size.height,
                "label": observation.labels.first?.identifier ?? "Unknown",
                "confidence": observation.confidence
            ]

            // 내부 맵을 외부 맵에 추가합니다.
            // 이 예에서는 인덱스를 키로 사용하였습니다.
            outerMap["box\(index)"] = innerMap
            
//            let labels = observation.labels.map { $0.identifier }.joined(separator: ", ")
//            print("Labels: \(labels)")
//            print("-----")
        }

        // 외부 맵을 Flutter로 전송합니다.
        guard let flutterViewController = flutterViewController else { return }
        let channel = FlutterMethodChannel(name: "camera_channel", binaryMessenger: flutterViewController.binaryMessenger)
        channel.invokeMethod("receiveCameraData", arguments: outerMap)
    }


}

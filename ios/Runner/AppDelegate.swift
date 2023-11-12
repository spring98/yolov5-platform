import UIKit
import Flutter

var flutterViewController: FlutterViewController?

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    var navigationController: UINavigationController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
      if let registrar = self.registrar(forPlugin: "CameraViewPlugin") {
          let factory = CameraViewFactory()
          registrar.register(
              factory,
              withId: "camera_view"
          )
      } else {
          print("Failed to get registrar for plugin CameraViewPlugin")
      }
      
      // method 추가
      flutterViewController = window?.rootViewController as? FlutterViewController
      let channel = FlutterMethodChannel(name: "camera_channel", binaryMessenger: flutterViewController!.binaryMessenger)
      channel.setMethodCallHandler { [weak self] (call, result) in
         if call.method == "triggerCamera" {
             
            let cameraView = CameraView(frame: flutterViewController!.view.frame)
            flutterViewController!.view.addSubview(cameraView)
             
             cameraView.translatesAutoresizingMaskIntoConstraints = false
               NSLayoutConstraint.activate([
                   cameraView.topAnchor.constraint(equalTo: flutterViewController!.view.topAnchor),
                   cameraView.bottomAnchor.constraint(equalTo: flutterViewController!.view.bottomAnchor),
                   cameraView.leadingAnchor.constraint(equalTo: flutterViewController!.view.leadingAnchor),
                   cameraView.trailingAnchor.constraint(equalTo: flutterViewController!.view.trailingAnchor)
               ])
             
             // Add debug log to print the frame of cameraView
             print("Camera view added: \(cameraView.frame)")

            result("Camera triggered")
         } else {
             result(FlutterMethodNotImplemented)
         }
      }
      
      // 기존 코드
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

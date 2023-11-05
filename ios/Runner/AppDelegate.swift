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
//             // Trigger the camera in a different ViewController
//             let cameraViewController = CameraViewController()
//
////             flutterViewController?.present(cameraViewController, animated: true, completion: nil)
//             // push 화면때 추가
//             self?.navigationController?.pushViewController(cameraViewController, animated: true)

            let cameraView = CameraView(frame: flutterViewController!.view.frame)
            flutterViewController!.view.addSubview(cameraView)
             
             cameraView.translatesAutoresizingMaskIntoConstraints = false
               NSLayoutConstraint.activate([
                   cameraView.topAnchor.constraint(equalTo: flutterViewController!.view.topAnchor),
                   cameraView.bottomAnchor.constraint(equalTo: flutterViewController!.view.bottomAnchor),
                   cameraView.leadingAnchor.constraint(equalTo: flutterViewController!.view.leadingAnchor),
                   cameraView.trailingAnchor.constraint(equalTo: flutterViewController!.view.trailingAnchor)
               ])
             
             print("Camera view added: \(cameraView.frame)")  // Add debug log to print the frame of cameraView

            result("Camera triggered")
         } else {
             result(FlutterMethodNotImplemented)
         }
      }
      
//      // push 화면때 추가
//      navigationController = UINavigationController(rootViewController: flutterViewController!)
//      window?.rootViewController = navigationController
//      window?.makeKeyAndVisible()
      
      // 기존 코드
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

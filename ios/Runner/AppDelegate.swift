import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let swimHealthChannel = SwimHealthChannel()
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Enregistre le channel HealthKit natif
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }
        
        if let registrar = self.registrar(forPlugin: "SwimHealthChannel") {
          swimHealthChannel.register(with: registrar)
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
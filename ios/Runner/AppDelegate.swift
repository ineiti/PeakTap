import UIKit
import Flutter

NSString* mapsApiKey = [[NSProcessInfo processInfo] environment[@"MAPS_API_KEY"];

[GMSServices provideAPIKey:mapsApiKey];

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
        GMSServices.provideAPIKey("AIzaSyAN2A18iW5X3a9zCL21QpfequZR1BpG6EU")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

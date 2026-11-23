import Flutter
import UIKit

/// T11 (SYSTEM_DESIGN 12.2): the iOS backup and transfer exclusion handler
/// for the `contour/backup_exclusions` method channel.
///
/// The handler sets `URLResourceKey.isExcludedFromBackupKey` on the
/// directory URL of the requested path kind. Paths are structural directory
/// paths sent by the Dart binding; the handler never logs them (AGENTS 2.6).
///
/// Device verification (S01 backup/transfer evidence) stays open: the
/// exclusion marker is device evidence, not a host test. PF-01 stays open:
/// exclusion flags cannot prove universal phone confinement.
private enum ContourBackupExclusions {
  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "apply":
      guard let args = call.arguments as? [String: Any],
            let rawPath = args["path"] as? String,
            !rawPath.isEmpty else {
        result(FlutterError(code: "badArgs", message: nil, details: nil))
        return
      }
      let url = URL(fileURLWithPath: rawPath, isDirectory: true)
      do {
        try (url as NSURL).setResourceValue(
          true, forKey: .isExcludedFromBackupKey)
        result(true)
      } catch {
        // No message text: the error carries no path content (AGENTS 2.6).
        result(FlutterError(code: "exclusionFailed", message: nil, details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(
      name: "contour/backup_exclusions", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      ContourBackupExclusions.handle(call, result: result)
    }
  }
}

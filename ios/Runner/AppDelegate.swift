import Flutter
import UIKit
import UniformTypeIdentifiers

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

/// P3-21 (SPEC 8.8): the PDF-only local file intake.
///
/// The handler presents the system document picker for one local PDF and
/// returns the bytes in memory. `asCopy` makes the picker hand over a
/// temporary copy; the handler reads it while the device is unlocked and
/// deletes it at once, so no raw file is retained (F06-D). The file is
/// checked against the 100 MiB bound and the `%PDF-` signature. It writes no
/// database row, takes no security-scoped access beyond the read and logs
/// nothing (AGENTS 2.6).
private final class ContourPdfIntake: NSObject, UIDocumentPickerDelegate {
  static var active: ContourPdfIntake?

  private let result: FlutterResult
  private let maxBytes: Int
  private var finished = false

  init(result: @escaping FlutterResult, maxBytes: Int) {
    self.result = result
    self.maxBytes = maxBytes
  }

  static func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard call.method == "pickPdf" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let presenter = presenter() else {
      result(FlutterError(code: "unavailable", message: nil, details: nil))
      return
    }
    let arguments = call.arguments as? [String: Any]
    let requested = arguments?["maxBytes"] as? Int ?? 0
    let bound = requested > 0 ? requested : 100 * 1024 * 1024

    let coordinator = ContourPdfIntake(result: result, maxBytes: bound)
    active = coordinator

    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: [UTType.pdf], asCopy: true)
    picker.delegate = coordinator
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  private static func presenter() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    var controller = scene?
      .windows
      .first(where: { $0.isKeyWindow })?
      .rootViewController
    while let presented = controller?.presentedViewController {
      controller = presented
    }
    return controller
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first else {
      finish(nil)
      return
    }
    finish(read(url))
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(nil)
  }

  private func read(_ url: URL) -> Any? {
    let scoped = url.startAccessingSecurityScopedResource()
    defer {
      if scoped { url.stopAccessingSecurityScopedResource() }
      // `asCopy` gave a temporary copy; no raw source stays on disk.
      try? FileManager.default.removeItem(at: url)
    }
    do {
      if let size = try url
        .resourceValues(forKeys: [.fileSizeKey])
        .fileSize, size > maxBytes {
        return FlutterError(code: "tooLarge", message: nil, details: nil)
      }
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      guard data.count <= maxBytes else {
        return FlutterError(code: "tooLarge", message: nil, details: nil)
      }
      guard data.count >= 5,
            Data(data.prefix(5)) == Data("%PDF-".utf8) else {
        return FlutterError(code: "notPdf", message: nil, details: nil)
      }
      return [
        "name": url.lastPathComponent,
        "bytes": FlutterStandardTypedData(bytes: data),
      ] as [String: Any]
    } catch {
      // No message text: the error carries no path or content (AGENTS 2.6).
      return FlutterError(code: "damaged", message: nil, details: nil)
    }
  }

  private func finish(_ value: Any?) {
    guard !finished else { return }
    finished = true
    if ContourPdfIntake.active === self {
      ContourPdfIntake.active = nil
    }
    result(value)
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
    let intake = FlutterMethodChannel(
      name: "contour/import_intake", binaryMessenger: messenger)
    intake.setMethodCallHandler { call, result in
      ContourPdfIntake.handle(call, result: result)
    }
  }
}

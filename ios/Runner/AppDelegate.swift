import Flutter
import UIKit
import UserNotifications
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var compass: CaminoCompass?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "CaminoCompass") {
      let handler = CaminoCompass()
      compass = handler
      FlutterEventChannel(name: "camino/compass", binaryMessenger: registrar.messenger())
        .setStreamHandler(handler)
    }
  }
}


/// Heading only: no additional GPS session or permission request.
private class CaminoCompass: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private var sink: FlutterEventSink?

  override init() {
    super.init()
    manager.delegate = self
    manager.headingFilter = kCLHeadingFilterNone
    NotificationCenter.default.addObserver(self, selector: #selector(stop),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    guard CLLocationManager.headingAvailable() else { events(nil); return nil }
    manager.startUpdatingHeading()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stop()
    sink = nil
    return nil
  }

  @objc private func stop() { manager.stopUpdatingHeading() }

  func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
    guard heading.headingAccuracy >= 0 else { sink?(nil); return }
    // Core Location defaults to the physical portrait top; remap to screen top.
    let orientation = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }?.interfaceOrientation
    let offset: Double
    switch orientation {
    case .landscapeLeft: offset = -90
    case .landscapeRight: offset = 90
    case .portraitUpsideDown: offset = 180
    default: offset = 0
    }
    let degrees = (heading.magneticHeading + offset + 360).truncatingRemainder(dividingBy: 360)
    sink?(["heading": degrees, "reliable": heading.headingAccuracy <= 30])
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { sink?(nil) }

  deinit {
    manager.stopUpdatingHeading()
    NotificationCenter.default.removeObserver(self)
  }
}

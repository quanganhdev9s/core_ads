import Flutter

public final class CoreAdsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "core_ads/language_start_native", binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      let key = args?["placementKey"] as? String
      switch call.method {
      case "setSelected":
        guard let key, let selected = args?["selected"] as? Bool else {
          result(FlutterError(
            code: "invalid_arguments", message: "placementKey and selected are required",
            details: nil
          ))
          return
        }
        NativeLanguageStartState.shared.setSelected(key, selected: selected)
        result(nil)
      case "clear":
        if let key { NativeLanguageStartState.shared.clear(key) }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

import Flutter

public final class CoreAdsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let collapsibleChannel = FlutterMethodChannel(
      name: "core_ads/collapsible_native", binaryMessenger: registrar.messenger()
    )
    collapsibleChannel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any]
      guard let key = args?["placementKey"] as? String else {
        result(FlutterError(
          code: "invalid_arguments", message: "placementKey is required", details: nil
        ))
        return
      }
      switch call.method {
      case "setCollapsed":
        guard let collapsed = args?["collapsed"] as? Bool else {
          result(FlutterError(
            code: "invalid_arguments", message: "collapsed is required", details: nil
          ))
          return
        }
        NativeCollapsibleState.shared.setCollapsed(
          key,
          collapsed: collapsed,
          collapsedFactoryId: args?["collapsedFactoryId"] as? String
        )
        result(nil)
      case "clear":
        NativeCollapsibleState.shared.clear(key)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

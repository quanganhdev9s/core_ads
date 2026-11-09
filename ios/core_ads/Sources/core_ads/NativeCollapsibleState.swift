import GoogleMobileAds

/// Rebinds a different layout to the same loaded native ad without another request.
final class NativeCollapsibleState {
  static let shared = NativeCollapsibleState()

  private struct Desired {
    let collapsed: Bool
    let collapsedFactoryId: String?
  }

  private final class Binding {
    weak var view: NativeAdView?
    weak var ad: NativeAd?
    let expandedTemplate: NativeAdTemplate
    let layouts: NativeAdLayouts
    let style: NativeAdStyle?
    var currentTemplate: NativeAdTemplate

    init(view: NativeAdView, ad: NativeAd, template: NativeAdTemplate, layouts: NativeAdLayouts,
         style: NativeAdStyle?) {
      self.view = view
      self.ad = ad
      self.expandedTemplate = template
      self.layouts = layouts
      self.style = style
      self.currentTemplate = template
    }
  }

  private var desiredByPlacement: [String: Desired] = [:]
  private var bindingsByPlacement: [String: [Binding]] = [:]

  func bind(
    _ placementKey: String, view: NativeAdView, ad: NativeAd,
    template: NativeAdTemplate, layouts: NativeAdLayouts, style: NativeAdStyle?
  ) {
    let binding = Binding(view: view, ad: ad, template: template, layouts: layouts,
                          style: style)
    bindingsByPlacement[placementKey, default: []].append(binding)
    if let desired = desiredByPlacement[placementKey] {
      apply(placementKey, binding: binding, desired: desired)
    }
  }

  func setCollapsed(
    _ placementKey: String, collapsed: Bool, collapsedFactoryId: String?
  ) {
    let desired = Desired(collapsed: collapsed, collapsedFactoryId: collapsedFactoryId)
    desiredByPlacement[placementKey] = desired
    guard var bindings = bindingsByPlacement[placementKey] else { return }
    bindings.removeAll { binding in
      guard binding.view != nil, binding.ad != nil else { return true }
      apply(placementKey, binding: binding, desired: desired)
      return false
    }
    bindingsByPlacement[placementKey] = bindings.isEmpty ? nil : bindings
  }

  func clear(_ placementKey: String) {
    desiredByPlacement.removeValue(forKey: placementKey)
    bindingsByPlacement.removeValue(forKey: placementKey)
  }

  func clearAll() {
    desiredByPlacement.removeAll()
    bindingsByPlacement.removeAll()
  }

  private func apply(_ placementKey: String, binding: Binding, desired: Desired) {
    let template = desired.collapsed
      ? (NativeAdTemplate(rawValue: desired.collapsedFactoryId ?? "") ?? .small1)
      : binding.expandedTemplate
    guard template != binding.currentTemplate,
      let view = binding.view, let ad = binding.ad else { return }
    binding.layouts.render(template, in: view, ad: ad, placementKey: placementKey,
                           style: binding.style)
    binding.currentTemplate = template
  }
}

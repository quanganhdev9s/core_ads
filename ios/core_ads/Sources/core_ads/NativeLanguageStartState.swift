import UIKit

/// Keeps the CTA registered with Google Mobile Ads while updating its appearance in place.
final class NativeLanguageStartState {
  static let shared = NativeLanguageStartState()

  private final class Binding {
    weak var button: UIButton?
    let variant: Int
    let fullWidth: NSLayoutConstraint?
    let compactWidth: NSLayoutConstraint?
    let height: NSLayoutConstraint?

    init(
      button: UIButton, variant: Int,
      fullWidth: NSLayoutConstraint?, compactWidth: NSLayoutConstraint?,
      height: NSLayoutConstraint?
    ) {
      self.button = button
      self.variant = variant
      self.fullWidth = fullWidth
      self.compactWidth = compactWidth
      self.height = height
    }
  }

  private var selectedByPlacement: [String: Bool] = [:]
  private var bindings: [String: Binding] = [:]

  func bind(
    _ placementKey: String, button: UIButton, variant: Int,
    fullWidth: NSLayoutConstraint? = nil,
    compactWidth: NSLayoutConstraint? = nil,
    height: NSLayoutConstraint? = nil
  ) {
    let binding = Binding(
      button: button, variant: variant,
      fullWidth: fullWidth, compactWidth: compactWidth, height: height
    )
    bindings[placementKey] = binding
    update(binding, selected: selectedByPlacement[placementKey] == true)
  }

  func setSelected(_ placementKey: String, selected: Bool) {
    selectedByPlacement[placementKey] = selected
    if let binding = bindings[placementKey] {
      update(binding, selected: selected)
    }
  }

  func clear(_ placementKey: String) {
    setSelected(placementKey, selected: false)
    selectedByPlacement.removeValue(forKey: placementKey)
  }

  func clearAll() {
    selectedByPlacement.removeAll()
    bindings.removeAll()
  }

  private func update(_ binding: Binding, selected: Bool) {
    guard let button = binding.button else { return }
    if binding.variant == 1 {
      guard let fullWidth = binding.fullWidth,
        let compactWidth = binding.compactWidth,
        let height = binding.height
      else { return }
      fullWidth.isActive = !selected
      compactWidth.isActive = selected
      height.constant = selected ? 40 : NativeAdDesign.buttonHeight
      button.superview?.layoutIfNeeded()
    } else {
      button.backgroundColor = selected
        ? NativeAdDesign.cta : NativeAdDesign.languageStartUnselectedCta
    }
  }
}

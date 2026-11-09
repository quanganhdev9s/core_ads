import GoogleMobileAds
import UIKit

/// Keys shared by Remote Config style values and the Flutter native factory option.
enum NativeAdStyleKeys {
  static let ctaBackground = "cta_bg"
  static let ctaText = "cta_text"
  static let ctaCornerDp = "cta_corner_dp"
  static let cardBackground = "card_bg"
  static let cardCornerDp = "card_corner_dp"
  static let cardStroke = "card_stroke"
  static let cardStrokeDp = "card_stroke_dp"
  static let titleColor = "title_color"
  static let bodyColor = "body_color"
  static let ctaHeightDp = "cta_height_dp"
  static let ctaTextSp = "cta_text_sp"
  static let titleTextSp = "title_text_sp"
  static let bodyTextSp = "body_text_sp"
  static let mediaHeightDp = "media_height_dp"
  static let iconSizeDp = "icon_size_dp"
  static let cardPaddingDp = "card_padding_dp"

  static let factoryOption = "nativeStyle"
}

/// Applies supplied ad_templates fields while retaining the base layout's other values.
final class NativeAdStyle {
  private let values: [String: Any]

  init?(options: Any?) {
    guard let options = options as? [AnyHashable: Any] else { return nil }
    let values = options.reduce(into: [String: Any]()) { result, entry in
      if let key = entry.key as? String { result[key] = entry.value }
    }
    guard !values.isEmpty else { return nil }
    self.values = values
  }

  private func number(_ key: String) -> CGFloat? {
    guard let value = values[key] as? NSNumber else { return nil }
    return CGFloat(truncating: value)
  }

  private func color(_ key: String) -> UIColor? {
    guard let raw = values[key] as? String, raw.first == "#" else { return nil }
    let digits = String(raw.dropFirst())
    guard (digits.count == 6 || digits.count == 8),
      let hex = UInt64(digits, radix: 16) else { return nil }
    let alpha = digits.count == 8 ? CGFloat((hex >> 24) & 0xFF) / 255 : 1
    return UIColor(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: alpha
    )
  }

  func apply(to root: NativeAdView, elements: NativeAdElements,
             template: NativeAdTemplate) {
    if let background = color(NativeAdStyleKeys.cardBackground) {
      root.backgroundColor = background
      if template == .full4 { root.mediaView?.backgroundColor = background }
    }
    if let corner = number(NativeAdStyleKeys.cardCornerDp) {
      root.layer.cornerRadius = corner
      root.clipsToBounds = true
    }
    if let stroke = color(NativeAdStyleKeys.cardStroke) {
      root.layer.borderColor = stroke.cgColor
      if number(NativeAdStyleKeys.cardStrokeDp) == nil { root.layer.borderWidth = 1 }
    }
    if let strokeWidth = number(NativeAdStyleKeys.cardStrokeDp),
      color(NativeAdStyleKeys.cardStroke) != nil || root.layer.borderWidth > 0 {
      root.layer.borderWidth = strokeWidth
      if root.layer.borderColor == nil {
        root.layer.borderColor = NativeAdDesign.outline.cgColor
      }
    }
    if let padding = number(NativeAdStyleKeys.cardPaddingDp) {
      for constraint in root.constraints {
        guard let child = constraint.firstItem as? UIView,
          let parent = constraint.secondItem as? UIView,
          child.superview === root, parent === root else { continue }
        switch constraint.firstAttribute {
        case .leading, .top: constraint.constant = padding
        case .trailing, .bottom: constraint.constant = -padding
        default: break
        }
      }
    }

    if let button = root.callToActionView as? UIButton {
      if let background = color(NativeAdStyleKeys.ctaBackground) { button.backgroundColor = background }
      if let corner = number(NativeAdStyleKeys.ctaCornerDp) { button.layer.cornerRadius = corner }
      if let height = number(NativeAdStyleKeys.ctaHeightDp) {
        let previousHeight = elements.callToActionHeightConstraint?.constant
        elements.callToActionHeightConstraint?.constant = height
        if let previousHeight {
          let delta = height - previousHeight
          if let parent = button.superview,
            let parentHeight = parent.constraints.first(where: {
              $0.firstItem as? UIView === parent && $0.firstAttribute == .height &&
                $0.secondItem == nil
            }), parentHeight.constant == previousHeight {
            parentHeight.constant = height
          } else if template.rawValue.hasPrefix("Full"),
            let panel = button.superview?.superview,
            let panelHeight = panel.constraints.first(where: {
              $0.firstItem as? UIView === panel && $0.firstAttribute == .height &&
                $0.secondItem == nil
            }) {
            panelHeight.constant += delta
          }
          if button.image(for: .normal) != nil {
            for constraint in button.constraints where
              constraint.firstItem as? UIView === button &&
              constraint.firstAttribute == .width && constraint.secondItem == nil {
              constraint.constant = height
            }
          }
        }
      }
      if let textColor = color(NativeAdStyleKeys.ctaText),
        let title = button.attributedTitle(for: .normal) {
        let updated = NSMutableAttributedString(attributedString: title)
        updated.addAttribute(.foregroundColor, value: textColor,
                             range: NSRange(location: 0, length: updated.length))
        button.setAttributedTitle(updated, for: .normal)
      }
      if let textSize = number(NativeAdStyleKeys.ctaTextSp),
        let title = button.attributedTitle(for: .normal) {
        let updated = NSMutableAttributedString(attributedString: title)
        updated.addAttribute(.font, value: NativeAdDesign.font(textSize, medium: true),
                             range: NSRange(location: 0, length: updated.length))
        button.setAttributedTitle(updated, for: .normal)
      }
    }
    updateLabel(elements.headline, color: color(NativeAdStyleKeys.titleColor),
                size: number(NativeAdStyleKeys.titleTextSp), medium: true)
    updateLabel(elements.body, color: color(NativeAdStyleKeys.bodyColor),
                size: number(NativeAdStyleKeys.bodyTextSp), medium: false)

    if let icon = root.iconView, let size = number(NativeAdStyleKeys.iconSizeDp) {
      for constraint in icon.constraints where constraint.secondItem == nil {
        if constraint.firstAttribute == .height || constraint.firstAttribute == .width {
          constraint.constant = size
        }
      }
    }
    if !template.rawValue.hasPrefix("Full"),
      let media = root.mediaView, let height = number(NativeAdStyleKeys.mediaHeightDp) {
      let previousHeight = media.constraints.first(where: {
        $0.firstItem as? UIView === media && $0.firstAttribute == .height &&
          $0.secondItem == nil
      })?.constant
      for constraint in media.constraints where constraint.secondItem == nil &&
        constraint.firstAttribute == .height {
        constraint.constant = height
        constraint.priority = .required
      }
      if let parent = media.superview, let previousHeight {
        for constraint in parent.constraints where
          constraint.firstItem as? UIView === parent &&
          constraint.firstAttribute == .height && constraint.secondItem == nil &&
          constraint.constant == previousHeight {
          constraint.constant = height
        }
      }
    }
  }

  private func updateLabel(_ label: UILabel, color: UIColor?, size: CGFloat?, medium: Bool) {
    guard color != nil || size != nil else { return }
    let text = NSMutableAttributedString(
      attributedString: label.attributedText ?? NSAttributedString(string: label.text ?? "")
    )
    let range = NSRange(location: 0, length: text.length)
    if let color { text.addAttribute(.foregroundColor, value: color, range: range) }
    if let size {
      text.addAttribute(.font, value: NativeAdDesign.font(size, medium: medium), range: range)
    }
    label.attributedText = text
  }
}

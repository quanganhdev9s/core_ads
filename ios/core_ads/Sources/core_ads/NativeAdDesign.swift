import CoreText
import GoogleMobileAds
import UIKit

/// Shared, explicit WaveZ native ad tokens. They do not resolve through iOS appearance colors.
enum NativeAdDesign {
  static let background = UIColor(hex: 0xFFFFFF)
  static let outline = UIColor(hex: 0xEBEBEB)
  static let title = UIColor(hex: 0x202020)
  static let body = UIColor(hex: 0x585858)
  static let darkBackground = UIColor(hex: 0x1B1B1B)
  static let darkTitle = UIColor(hex: 0xFBFBFB)
  static let darkBody = UIColor(hex: 0xCACACA)
  static let cta = UIColor(hex: 0x017FE6)
  static let languageStartUnselectedCta = UIColor(hex: 0x7E2D96)
  static let badge = UIColor(hex: 0xF8C600)
  static let star = UIColor(hex: 0xEBBC00)
  static let mediaPlaceholder = UIColor(hex: 0x0E0A15)

  static let cardRadius: CGFloat = 12
  static let cardInset: CGFloat = 13 // 1pt outline + 12pt design padding
  static let gap: CGFloat = 8
  static let iconSize: CGFloat = 48
  static let buttonHeight: CGFloat = 48
  static let ctaFontSize: CGFloat = 14
  static let ctaLineHeight: CGFloat = 20
  static let ctaPaddingVertical: CGFloat = 4
  static let ctaPaddingHorizontal: CGFloat = 12
  static let mediaRadius: CGFloat = 8

  static func card(_ view: UIView, dark: Bool = false, fullScreen: Bool = false) {
    view.backgroundColor = dark ? darkBackground : background
    view.layer.cornerRadius = fullScreen ? 0 : cardRadius
    view.layer.borderWidth = dark || fullScreen ? 0 : 1
    view.layer.borderColor = dark || fullScreen ? nil : outline.cgColor
    view.clipsToBounds = true
  }

  static func font(_ size: CGFloat, medium: Bool = false) -> UIFont {
    _ = registerFont
    return UIFont(name: medium ? "Roboto-Medium" : "Roboto-Regular", size: size)
      ?? UIFont.systemFont(ofSize: size, weight: medium ? .medium : .regular)
  }

  static func image(_ name: String) -> UIImage? {
    guard let path = resourceBundle.path(forResource: name, ofType: "png"),
      let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage
    else { return nil }
    return UIImage(cgImage: cgImage, scale: 3, orientation: .up)
  }

  private static var resourceBundle: Bundle {
    #if SWIFT_PACKAGE
    Bundle.module
    #else
    let bundle = Bundle(for: CoreAdsNativeFactory.self)
    return bundle.url(forResource: "core_ads", withExtension: "bundle")
      .flatMap(Bundle.init(url:)) ?? bundle
    #endif
  }

  private static let registerFont: Void = {
    let url = resourceBundle.url(
      forResource: "Roboto-VariableFont_wdth_wght", withExtension: "ttf"
    )
    if let url {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }()

  static func label(
    _ value: String?, size: CGFloat, medium: Bool, color: UIColor,
    lines: Int = 1, lineHeight: CGFloat
  ) -> UILabel {
    let label = UILabel()
    label.font = font(size, medium: medium)
    label.textColor = color
    label.numberOfLines = lines
    label.lineBreakMode = .byTruncatingTail
    label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    label.adjustsFontForContentSizeCategory = false
    if let value {
      let paragraph = NSMutableParagraphStyle()
      paragraph.minimumLineHeight = lineHeight
      paragraph.maximumLineHeight = lineHeight
      paragraph.lineBreakMode = .byTruncatingTail
      label.attributedText = NSAttributedString(
        string: value,
        attributes: [.font: label.font as Any, .foregroundColor: color, .paragraphStyle: paragraph]
      )
    }
    return label
  }

  static func badgeLabel() -> UILabel {
    let label = InsetLabel(insets: UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4))
    label.font = font(10, medium: true)
    label.text = "Ad"
    label.textColor = background
    label.textAlignment = .center
    label.backgroundColor = badge
    label.layer.cornerRadius = 4
    label.clipsToBounds = true
    label.setContentHuggingPriority(.required, for: .horizontal)
    label.setContentCompressionResistancePriority(.required, for: .horizontal)
    return label
  }

  static func stack(_ axis: NSLayoutConstraint.Axis, spacing: CGFloat = 0) -> UIStackView {
    let stack = UIStackView()
    stack.axis = axis
    stack.spacing = spacing
    stack.alignment = .fill
    stack.distribution = .fill
    stack.translatesAutoresizingMaskIntoConstraints = false
    return stack
  }

  static func pin(_ child: UIView, to parent: UIView, inset: CGFloat = 0) {
    child.translatesAutoresizingMaskIntoConstraints = false
    parent.addSubview(child)
    NSLayoutConstraint.activate([
      child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: inset),
      child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -inset),
      child.topAnchor.constraint(equalTo: parent.topAnchor, constant: inset),
      child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -inset),
    ])
  }

  static func height(_ view: UIView, _ value: CGFloat) {
    view.translatesAutoresizingMaskIntoConstraints = false
    view.heightAnchor.constraint(equalToConstant: value).isActive = true
  }
}

private extension UIColor {
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}

private final class InsetLabel: UILabel {
  private let insets: UIEdgeInsets

  init(insets: UIEdgeInsets) {
    self.insets = insets
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { return nil }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(
      width: size.width + insets.left + insets.right,
      height: size.height + insets.top + insets.bottom
    )
  }

  override func drawText(in rect: CGRect) {
    super.drawText(in: rect.inset(by: insets))
  }
}

private final class InsetButton: UIButton {
  private let insets: UIEdgeInsets

  init(insets: UIEdgeInsets) {
    self.insets = insets
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) { return nil }

  override var intrinsicContentSize: CGSize {
    let size = super.intrinsicContentSize
    return CGSize(
      width: size.width + insets.left + insets.right,
      height: size.height + insets.top + insets.bottom
    )
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    titleLabel?.frame = bounds.inset(by: insets)
  }
}

/// A single set of ad asset views, composed by the selected layout.
final class NativeAdElements {
  let ad: NativeAd
  let headline: UILabel
  let body: UILabel
  private(set) var iconView: UIImageView?
  private(set) var mediaView: MediaView?
  private(set) var callToActionView: UIView?
  private(set) var callToActionHeightConstraint: NSLayoutConstraint?
  private(set) var starRatingView: UIView?

  init(ad: NativeAd, dark: Bool) {
    self.ad = ad
    headline = NativeAdDesign.label(
      ad.headline, size: 14, medium: true,
      color: dark ? NativeAdDesign.darkTitle : NativeAdDesign.title,
      lineHeight: 20
    )
    body = NativeAdDesign.label(
      ad.body, size: 12, medium: false,
      color: dark ? NativeAdDesign.darkBody : NativeAdDesign.body,
      lines: 2, lineHeight: 16
    )
    body.isHidden = ad.body?.isEmpty ?? true
  }

  func icon(size: CGFloat = NativeAdDesign.iconSize) -> UIImageView {
    let view = UIImageView(image: ad.icon?.image)
    view.contentMode = .scaleAspectFill
    view.backgroundColor = NativeAdDesign.mediaPlaceholder
    view.layer.cornerRadius = size == 96 ? 16 : 8
    view.clipsToBounds = true
    view.isHidden = ad.icon?.image == nil
    NativeAdDesign.height(view, size)
    view.widthAnchor.constraint(equalToConstant: size).isActive = true
    iconView = view
    return view
  }

  func media() -> MediaView {
    let view = MediaView()
    view.mediaContent = ad.mediaContent
    view.contentMode = .scaleAspectFit
    view.backgroundColor = .clear
    view.isOpaque = false
    view.layer.cornerRadius = NativeAdDesign.mediaRadius
    view.clipsToBounds = true
    mediaView = view
    return view
  }

  func button(circle: Bool = false) -> UIButton {
    let button: UIButton = circle ? UIButton(type: .custom) : InsetButton(insets: UIEdgeInsets(
      top: NativeAdDesign.ctaPaddingVertical,
      left: NativeAdDesign.ctaPaddingHorizontal,
      bottom: NativeAdDesign.ctaPaddingVertical,
      right: NativeAdDesign.ctaPaddingHorizontal
    ))
    button.backgroundColor = NativeAdDesign.cta
    button.layer.cornerRadius = 24
    button.clipsToBounds = true
    button.isUserInteractionEnabled = false // Google Mobile Ads handles clicks on registered asset views.
    button.isHidden = ad.callToAction?.isEmpty ?? true
    button.accessibilityLabel = ad.callToAction
    button.titleLabel?.numberOfLines = 1
    button.titleLabel?.lineBreakMode = .byTruncatingTail
    button.titleLabel?.adjustsFontSizeToFitWidth = false
    if circle {
      button.setImage(NativeAdDesign.image("ad_arrow_3x"), for: .normal)
    } else {
      let paragraph = NSMutableParagraphStyle()
      paragraph.minimumLineHeight = NativeAdDesign.ctaLineHeight
      paragraph.maximumLineHeight = NativeAdDesign.ctaLineHeight
      paragraph.alignment = .center
      paragraph.lineBreakMode = .byTruncatingTail
      button.setAttributedTitle(NSAttributedString(
        string: ad.callToAction ?? "",
        attributes: [
          .font: NativeAdDesign.font(NativeAdDesign.ctaFontSize, medium: true),
          .foregroundColor: NativeAdDesign.background,
          .paragraphStyle: paragraph,
        ]
      ), for: .normal)
    }
    button.translatesAutoresizingMaskIntoConstraints = false
    let height = button.heightAnchor.constraint(equalToConstant: NativeAdDesign.buttonHeight)
    height.isActive = true
    callToActionHeightConstraint = height
    callToActionView = button
    return button
  }

  func textColumn(
    badgeInTitle: Bool = true, meta: NativeAdMeta = .none,
    showBody: Bool = true, bodyLines: Int = 1
  ) -> UIStackView {
    let column = NativeAdDesign.stack(.vertical, spacing: 2)
    body.numberOfLines = bodyLines
    let titleRow = NativeAdDesign.stack(.horizontal, spacing: 4)
    titleRow.alignment = .center
    if badgeInTitle { titleRow.addArrangedSubview(NativeAdDesign.badgeLabel()) }
    titleRow.addArrangedSubview(headline)
    NativeAdDesign.height(titleRow, 20)
    column.addArrangedSubview(titleRow)
    if meta != .none { column.addArrangedSubview(metaRow(meta)) }
    if showBody {
      NativeAdDesign.height(body, CGFloat(bodyLines) * 16)
      column.addArrangedSubview(body)
    }
    return column
  }

  func infoRow(
    iconSize: CGFloat = NativeAdDesign.iconSize,
    badgeInTitle: Bool = true, meta: NativeAdMeta = .none,
    showBody: Bool = true, bodyLines: Int = 1
  ) -> UIStackView {
    let row = NativeAdDesign.stack(.horizontal, spacing: NativeAdDesign.gap)
    row.alignment = .top
    row.addArrangedSubview(icon(size: iconSize))
    row.addArrangedSubview(textColumn(
      badgeInTitle: badgeInTitle, meta: meta,
      showBody: showBody, bodyLines: bodyLines
    ))
    return row
  }

  private func metaRow(_ style: NativeAdMeta) -> UIStackView {
    let row = NativeAdDesign.stack(.horizontal, spacing: 6)
    row.alignment = .center
    if style == .badge || style == .badgeStarsFree {
      row.addArrangedSubview(NativeAdDesign.badgeLabel())
    }
    if style == .stars || style == .badgeStarsFree {
      let rating = ad.starRating?.intValue ?? 0
      let stars = NativeAdDesign.stack(.horizontal)
      stars.isHidden = rating == 0
      for _ in 0..<max(0, min(rating, 5)) {
        let star = UIImageView(image: NativeAdDesign.image("ad_star_3x"))
        star.contentMode = .scaleAspectFit
        stars.addArrangedSubview(star)
        star.widthAnchor.constraint(equalToConstant: 14).isActive = true
      }
      NativeAdDesign.height(stars, 14)
      row.addArrangedSubview(stars)
      starRatingView = stars
    }
    if style == .badgeStarsFree {
      row.addArrangedSubview(NativeAdDesign.label(
        "FREE", size: 10, medium: true,
        color: NativeAdDesign.body, lineHeight: 12
      ))
    }
    row.addArrangedSubview(UIView())
    NativeAdDesign.height(row, style == .stars ? 14 : 16)
    return row
  }

  func bind(to view: NativeAdView) {
    view.headlineView = headline
    view.bodyView = body.superview == nil ? nil : body
    view.iconView = iconView
    view.mediaView = mediaView
    view.callToActionView = callToActionView
    view.starRatingView = starRatingView
    view.nativeAd = ad
  }
}

enum NativeAdMeta { case none, stars, badge, badgeStarsFree }

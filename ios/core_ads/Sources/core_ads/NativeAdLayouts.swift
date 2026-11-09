import GoogleMobileAds
import UIKit

/// Factory IDs shared with Android, plus the Card1 layout in the iOS design.
enum NativeAdTemplate: String, CaseIterable {
  case tiny1 = "Tiny1", tiny2 = "Tiny2"
  case small1 = "Small1", small2 = "Small2", small3 = "Small3", small4 = "Small4"
  case small5 = "Small5"
  case big1 = "Big1", big2 = "Big2", big3 = "Big3", big4 = "Big4", big5 = "Big5"
  case big6 = "Big6", big7 = "Big7", big8 = "Big8", big9 = "Big9"
  case languageStart1 = "LanguageStart1", languageStart2 = "LanguageStart2"
  case full1 = "Full1", full2 = "Full2", full3 = "Full3", full4 = "Full4", full5 = "Full5"
  case collap1Expanded = "Collap1Expanded", collap1Collapsed = "Collap1Collapsed"
  case collap2Expanded = "Collap2Expanded", collap2Collapsed = "Collap2Collapsed"
  case collap3Expanded = "Collap3Expanded", collap3Collapsed = "Collap3Collapsed"
  case card1 = "Card1"
}

/// Composes one set of SDK asset views into an iPhone or iPad native layout.
final class NativeAdLayouts {
  private let isPad: Bool

  init(isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad) {
    self.isPad = isPad
  }

  func build(
    _ template: NativeAdTemplate, ad: NativeAd, placementKey: String? = nil,
    style: NativeAdStyle? = nil
  ) -> NativeAdView {
    let root = NativeAdView()
    render(template, in: root, ad: ad, placementKey: placementKey, style: style)
    return root
  }

  func render(
    _ template: NativeAdTemplate, in root: NativeAdView,
    ad: NativeAd, placementKey: String? = nil, style: NativeAdStyle? = nil
  ) {
    root.subviews.forEach { $0.removeFromSuperview() }
    let dark = template == .full4
    let elements = NativeAdElements(ad: ad, dark: dark)
    NativeAdDesign.card(
      root,
      dark: dark,
      fullScreen: template.rawValue.hasPrefix("Full")
    )

    switch template {
    case .tiny1:
      compact(root, elements: elements, circle: false)
    case .tiny2:
      compact(root, elements: elements, circle: true)
    case .collap1Collapsed:
      collap1Collapsed(root, elements: elements)
    case .collap2Collapsed:
      collap2Collapsed(root, elements: elements)
    case .collap3Collapsed:
      collap3Collapsed(root, elements: elements)
    case .small1:
      small(root, elements: elements, variant: 1)
    case .small2:
      small(root, elements: elements, variant: 2)
    case .small3, .small5:
      small(root, elements: elements, variant: 3)
    case .small4:
      small(root, elements: elements, variant: 4)
    case .big1:
      big(root, elements: elements, variant: 1)
    case .collap1Expanded:
      collap1Expanded(root, elements: elements)
    case .big2, .big6:
      big(root, elements: elements, variant: 2)
    case .big3, .big7:
      big(root, elements: elements, variant: 3)
    case .big4, .big8:
      big(root, elements: elements, variant: 4)
    case .big5, .big9:
      big(root, elements: elements, variant: 5)
    case .languageStart1:
      languageStart(root, elements: elements, variant: 1)
    case .languageStart2:
      languageStart(root, elements: elements, variant: 2)
    case .full1:
      full(root, elements: elements, variant: 1)
    case .full2, .full4:
      full(root, elements: elements, variant: 2)
    case .full3, .full5:
      full(root, elements: elements, variant: 3)
    case .collap2Expanded, .collap3Expanded:
      collapsible(root, elements: elements)
    case .card1:
      card(root, elements: elements)
    }
    elements.bind(to: root)
    style?.apply(to: root, elements: elements, template: template)
  }

  private func column(in root: NativeAdView) -> UIStackView {
    let stack = NativeAdDesign.stack(.vertical, spacing: NativeAdDesign.gap)
    NativeAdDesign.pin(stack, to: root, inset: NativeAdDesign.cardInset)
    return stack
  }

  private func media(
    _ elements: NativeAdElements,
    height: CGFloat,
    flexible: Bool = false
  ) -> MediaView {
    let view = elements.media()
    view.translatesAutoresizingMaskIntoConstraints = false
    let heightConstraint = view.heightAnchor.constraint(equalToConstant: height)
    heightConstraint.priority = flexible ? .defaultLow : .required
    heightConstraint.isActive = true
    return view
  }

  private func compact(_ root: NativeAdView, elements: NativeAdElements, circle: Bool) {
    let row = NativeAdDesign.stack(.horizontal, spacing: NativeAdDesign.gap)
    row.alignment = .center
    NativeAdDesign.pin(row, to: root, inset: NativeAdDesign.cardInset)
    row.addArrangedSubview(elements.icon(size: 40))
    row.addArrangedSubview(elements.textColumn(bodyLines: circle ? 1 : 2))
    let button = elements.button(circle: circle)
    if circle {
      row.addArrangedSubview(button)
      button.widthAnchor.constraint(equalToConstant: 48).isActive = true
    } else {
      addConstrainedTextButton(button, to: row)
    }
    NativeAdDesign.height(row, circle ? 48 : 54)
  }

  private func small(_ root: NativeAdView, elements: NativeAdElements, variant: Int) {
    let stack = column(in: root)
    switch variant {
    case 1:
      let info = elements.infoRow(badgeInTitle: false, meta: .badgeStarsFree)
      NativeAdDesign.height(info, 56)
      stack.addArrangedSubview(info)
      stack.addArrangedSubview(elements.button())
    case 2:
      let row = NativeAdDesign.stack(.horizontal, spacing: NativeAdDesign.gap)
      let details = NativeAdDesign.stack(.vertical, spacing: NativeAdDesign.gap)
      details.addArrangedSubview(elements.textColumn(bodyLines: 2))
      details.addArrangedSubview(UIView())
      details.addArrangedSubview(elements.button())
      row.addArrangedSubview(details)
      let imageSize: CGFloat = isPad ? 140 : 120
      let image = media(elements, height: imageSize)
      image.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
      row.addArrangedSubview(image)
      NativeAdDesign.height(row, isPad ? 140 : 120)
      stack.addArrangedSubview(row)
    case 3:
      let row = NativeAdDesign.stack(.horizontal, spacing: NativeAdDesign.gap)
      row.alignment = .top
      let imageSize: CGFloat = isPad ? 140 : 120
      let image = media(elements, height: imageSize)
      image.widthAnchor.constraint(equalToConstant: imageSize).isActive = true
      row.addArrangedSubview(image)
      let details = NativeAdDesign.stack(.vertical, spacing: NativeAdDesign.gap)
      let text = elements.textColumn(bodyLines: 2)
      details.addArrangedSubview(text)
      let spacer = UIView()
      details.addArrangedSubview(spacer)
      details.addArrangedSubview(elements.button())
      row.addArrangedSubview(details)
      NativeAdDesign.height(row, imageSize)
      stack.addArrangedSubview(row)
    default:
      stack.addArrangedSubview(elements.button())
      let info = elements.infoRow()
      NativeAdDesign.height(info, 48)
      stack.addArrangedSubview(info)
    }
  }

  private func big(_ root: NativeAdView, elements: NativeAdElements, variant: Int) {
    let stack = column(in: root)
    switch variant {
    case 1:
      let info = elements.infoRow()
      NativeAdDesign.height(info, 48)
      stack.addArrangedSubview(info)
      stack.addArrangedSubview(media(elements, height: 218, flexible: true))
      stack.addArrangedSubview(elements.button())
    case 2:
      let info = elements.infoRow()
      NativeAdDesign.height(info, 48)
      stack.addArrangedSubview(info)
      stack.addArrangedSubview(media(elements, height: 218, flexible: true))
      stack.addArrangedSubview(trailingButton(elements))
    case 3:
      let title = elements.textColumn(showBody: false)
      NativeAdDesign.height(title, 20)
      stack.addArrangedSubview(title)
      stack.addArrangedSubview(media(elements, height: 218, flexible: true))
      stack.addArrangedSubview(elements.button())
    case 4:
      stack.addArrangedSubview(elements.button())
      stack.addArrangedSubview(media(elements, height: 218, flexible: true))
      let title = elements.textColumn(showBody: false)
      NativeAdDesign.height(title, 20)
      stack.addArrangedSubview(title)
    default:
      stack.addArrangedSubview(media(elements, height: 218, flexible: true))
      stack.addArrangedSubview(titleAndButton(elements))
    }
  }

  private func languageStart(
    _ root: NativeAdView,
    elements: NativeAdElements,
    variant: Int
  ) {
    let stack = column(in: root)
    let button = elements.button()
    if variant == 2 {
      button.backgroundColor = NativeAdDesign.languageStartUnselectedCta
      stack.addArrangedSubview(button)
    }
    stack.addArrangedSubview(media(elements, height: 218, flexible: true))
    let info = elements.infoRow(
      iconSize: 40, badgeInTitle: false, meta: .badgeStarsFree
    )
    NativeAdDesign.height(info, 56)
    stack.addArrangedSubview(info)
    if variant == 1 {
      let area = UIView()
      NativeAdDesign.height(area, NativeAdDesign.buttonHeight)
      stack.addArrangedSubview(area)
      button.translatesAutoresizingMaskIntoConstraints = false
      area.addSubview(button)
      NSLayoutConstraint.activate([
        button.trailingAnchor.constraint(equalTo: area.trailingAnchor),
        button.centerYAnchor.constraint(equalTo: area.centerYAnchor),
        button.widthAnchor.constraint(equalTo: area.widthAnchor),
      ])
    }
  }

  private func collapsible(_ root: NativeAdView, elements: NativeAdElements) {
    let stack = column(in: root)
    let header = elements.textColumn(showBody: false)
    NativeAdDesign.height(header, 28)
    stack.addArrangedSubview(header)
    stack.addArrangedSubview(media(elements, height: 218, flexible: true))
    stack.addArrangedSubview(elements.button())
    // AdsCollapsibleNative overlays the close control and owns the collapse action.
  }

  // Collap1 uses the same assets as Big1, with media above the app details.
  private func collap1Expanded(_ root: NativeAdView, elements: NativeAdElements) {
    let stack = column(in: root)
    stack.addArrangedSubview(media(elements, height: 218, flexible: true))
    let info = elements.infoRow()
    NativeAdDesign.height(info, 48)
    stack.addArrangedSubview(info)
    stack.addArrangedSubview(elements.button())
  }

  private func collap1Collapsed(_ root: NativeAdView, elements: NativeAdElements) {
    compact(root, elements: elements, circle: false)
  }

  private func collap2Collapsed(_ root: NativeAdView, elements: NativeAdElements) {
    compact(root, elements: elements, circle: false)
  }

  private func collap3Collapsed(_ root: NativeAdView, elements: NativeAdElements) {
    compact(root, elements: elements, circle: false)
  }

  private func full(_ root: NativeAdView, elements: NativeAdElements, variant: Int) {
    let stack = NativeAdDesign.stack(.vertical)
    NativeAdDesign.pin(stack, to: root)
    if variant == 2 {
      let header = UIView()
      let badge = NativeAdDesign.badgeLabel()
      badge.translatesAutoresizingMaskIntoConstraints = false
      header.addSubview(badge)
      NSLayoutConstraint.activate([
        badge.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
        badge.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
        badge.heightAnchor.constraint(equalToConstant: 16),
      ])
      NativeAdDesign.height(header, 40)
      stack.addArrangedSubview(header)
    }
    let mediaArea = UIView()
    mediaArea.clipsToBounds = true
    let adMedia = elements.media()
    adMedia.translatesAutoresizingMaskIntoConstraints = false
    mediaArea.addSubview(adMedia)
    if variant == 2 {
      NSLayoutConstraint.activate([
        adMedia.leadingAnchor.constraint(equalTo: mediaArea.leadingAnchor),
        adMedia.trailingAnchor.constraint(equalTo: mediaArea.trailingAnchor),
        adMedia.topAnchor.constraint(equalTo: mediaArea.topAnchor),
        adMedia.bottomAnchor.constraint(equalTo: mediaArea.bottomAnchor),
      ])
    } else {
      let mediaHeight: CGFloat = variant == 1 ? 412 : 232
      NSLayoutConstraint.activate([
        adMedia.leadingAnchor.constraint(equalTo: mediaArea.leadingAnchor),
        adMedia.trailingAnchor.constraint(equalTo: mediaArea.trailingAnchor),
        adMedia.centerYAnchor.constraint(equalTo: mediaArea.centerYAnchor),
        adMedia.heightAnchor.constraint(equalToConstant: mediaHeight),
      ])
    }
    if variant != 2 {
      let badge = NativeAdDesign.badgeLabel()
      badge.translatesAutoresizingMaskIntoConstraints = false
      mediaArea.addSubview(badge)
      NSLayoutConstraint.activate([
        badge.leadingAnchor.constraint(equalTo: mediaArea.leadingAnchor, constant: 12),
        badge.topAnchor.constraint(equalTo: mediaArea.topAnchor, constant: 12),
        badge.heightAnchor.constraint(equalToConstant: 16),
      ])
    }
    stack.addArrangedSubview(mediaArea)

    let panel = UIView()
    let content = NativeAdDesign.stack(.vertical, spacing: 12)
    NativeAdDesign.pin(content, to: panel, inset: 16)
    let info = elements.infoRow(
      badgeInTitle: false,
      meta: variant == 1 ? .stars : .none
    )
    NativeAdDesign.height(info, variant == 1 ? 56 : 48)
    content.addArrangedSubview(info)
    content.addArrangedSubview(elements.button())
    NativeAdDesign.height(panel, variant == 1 ? 148 : 140)
    stack.addArrangedSubview(panel)
    // The full-screen Flutter widget owns Close and Next navigation controls.
  }

  private func card(_ root: NativeAdView, elements: NativeAdElements) {
    let stack = NativeAdDesign.stack(.vertical, spacing: NativeAdDesign.gap)
    NativeAdDesign.pin(stack, to: root, inset: 12)
    let mediaRow = UIView()
    let image = media(elements, height: 120)
    image.widthAnchor.constraint(equalToConstant: 120).isActive = true
    image.translatesAutoresizingMaskIntoConstraints = false
    mediaRow.addSubview(image)
    NSLayoutConstraint.activate([
      image.centerXAnchor.constraint(equalTo: mediaRow.centerXAnchor),
      image.centerYAnchor.constraint(equalTo: mediaRow.centerYAnchor),
    ])
    NativeAdDesign.height(mediaRow, 120)
    stack.addArrangedSubview(mediaRow)
    stack.setCustomSpacing(0, after: mediaRow)
    stack.addArrangedSubview(UIView())
    let title = elements.textColumn(showBody: false)
    NativeAdDesign.height(title, 20)
    stack.addArrangedSubview(title)
    stack.addArrangedSubview(elements.button())
  }

  private func trailingButton(_ elements: NativeAdElements) -> UIStackView {
    let row = NativeAdDesign.stack(.horizontal)
    row.addArrangedSubview(UIView())
    let button = elements.button()
    addConstrainedTextButton(button, to: row)
    NativeAdDesign.height(row, NativeAdDesign.buttonHeight)
    return row
  }

  private func titleAndButton(_ elements: NativeAdElements) -> UIStackView {
    let row = NativeAdDesign.stack(.horizontal, spacing: NativeAdDesign.gap)
    row.alignment = .center
    row.addArrangedSubview(elements.textColumn(showBody: false))
    let button = elements.button()
    addConstrainedTextButton(button, to: row)
    NativeAdDesign.height(row, NativeAdDesign.buttonHeight)
    return row
  }

  private func addConstrainedTextButton(_ button: UIView, to row: UIStackView) {
    row.addArrangedSubview(button)
    button.setContentHuggingPriority(.required, for: .horizontal)
    button.widthAnchor.constraint(
      lessThanOrEqualTo: row.widthAnchor, multiplier: 1.0 / 3.0
    ).isActive = true
  }
}

package com.quanganh.core_ads

import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView

internal enum class NativeAdTemplate(val factoryId: String) {
    Tiny1("Tiny1"), Tiny2("Tiny2"),
    Small1("Small1"), Small2("Small2"), Small3("Small3"), Small4("Small4"),
    Small5("Small5"),
    Big1("Big1"), Big2("Big2"), Big3("Big3"), Big4("Big4"), Big5("Big5"),
    Big6("Big6"), Big7("Big7"), Big8("Big8"), Big9("Big9"),
    LanguageStart1("LanguageStart1"), LanguageStart2("LanguageStart2"),
    Full1("Full1"), Full2("Full2"), Full3("Full3"), Full4("Full4"), Full5("Full5"),
    Collap1Expanded("Collap1Expanded"), Collap1Collapsed("Collap1Collapsed"),
    Collap2Expanded("Collap2Expanded"), Collap2Collapsed("Collap2Collapsed"),
    Collap3Expanded("Collap3Expanded"), Collap3Collapsed("Collap3Collapsed"),
    Card1("Card1"),
}

/** Composes the same ad assets into the Android Figma variants. */
internal class NativeAdLayouts(private val context: Context) {
    private fun dp(value: Int) = NativeAdDesign.dp(context, value)
    private fun match(height: Int = ViewGroup.LayoutParams.WRAP_CONTENT) =
        LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, height)
    private fun gap(value: Int = NativeAdDesign.itemGap) = View(context).apply {
        layoutParams = match(dp(value))
    }

    fun build(template: NativeAdTemplate, ad: NativeAd, placementKey: String? = null): NativeAdView {
        val dark = template == NativeAdTemplate.Full2 || template == NativeAdTemplate.Full4
        val elements = NativeAdElements(context, ad, dark)
        val root = NativeAdView(context)
        val content = when (template) {
            NativeAdTemplate.Tiny1 -> tiny(elements, circle = false)
            NativeAdTemplate.Tiny2 -> tiny(elements, circle = true)
            NativeAdTemplate.Collap1Collapsed -> collap1Collapsed(elements)
            NativeAdTemplate.Collap2Collapsed -> collap2Collapsed(elements)
            NativeAdTemplate.Collap3Collapsed -> collap3Collapsed(elements)
            NativeAdTemplate.Small1 -> small(elements, 1)
            NativeAdTemplate.Small2 -> small(elements, 2)
            NativeAdTemplate.Small3, NativeAdTemplate.Small5 -> small(elements, 3)
            NativeAdTemplate.Small4 -> small(elements, 4)
            NativeAdTemplate.Big1 -> big(elements, 1)
            NativeAdTemplate.Big2 -> big(elements, 2)
            NativeAdTemplate.Big3 -> big(elements, 3)
            NativeAdTemplate.Big4 -> big(elements, 4)
            NativeAdTemplate.Collap1Expanded -> collap1Expanded(elements)
            NativeAdTemplate.Big5 -> big(elements, 5)
            NativeAdTemplate.Big6 -> big(elements, 6)
            NativeAdTemplate.Big7 -> big(elements, 7)
            NativeAdTemplate.Big8 -> big(elements, 8)
            NativeAdTemplate.Big9 -> big(elements, 9)
            NativeAdTemplate.LanguageStart1 -> languageStart(elements, 1, placementKey)
            NativeAdTemplate.LanguageStart2 -> languageStart(elements, 2, placementKey)
            NativeAdTemplate.Full1 -> full(elements, 1)
            NativeAdTemplate.Full2 -> full(elements, 2)
            NativeAdTemplate.Full3 -> full(elements, 3)
            NativeAdTemplate.Full4 -> full(elements, 4)
            NativeAdTemplate.Full5 -> full(elements, 5)
            NativeAdTemplate.Collap2Expanded -> collapsible(elements, 2)
            NativeAdTemplate.Collap3Expanded -> collapsible(elements, 3)
            NativeAdTemplate.Card1 -> card(elements)
        }
        root.addView(content, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            if (template.name.startsWith("Full") ||
                template.name.startsWith("Big") ||
                template.name.endsWith("Expanded")) ViewGroup.LayoutParams.MATCH_PARENT
            else ViewGroup.LayoutParams.WRAP_CONTENT,
        ))
        elements.bind(root)
        return root
    }

    private fun media(elements: NativeAdElements): View =
        RatioMedia(context).apply {
            addView(elements.media(), FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            ))
        }

    private fun flexibleMediaParams() = match(0).apply { weight = 1f }

    private fun languageStart(
        elements: NativeAdElements,
        variant: Int,
        placementKey: String?,
    ) = NativeAdDesign.card(context).apply {
        val button = elements.cta() as TextView
        if (variant == 2) {
            addView(button, match(dp(NativeAdDesign.buttonHeight)))
            addView(gap())
        }
        addView(media(elements), flexibleMediaParams())
        addView(gap())
        addView(elements.infoRow(
            iconSize = NativeAdDesign.iconSmall,
            badgeInTitle = false,
            meta = MetaStyle.BADGE_STARS_FREE,
        ), match())
        if (variant == 1) {
            addView(gap())
            addView(FrameLayout(context).apply {
                addView(button, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(NativeAdDesign.buttonHeight),
                    Gravity.END or Gravity.CENTER_VERTICAL,
                ))
            }, match(dp(NativeAdDesign.buttonHeight)))
        }
        if (placementKey != null) {
            NativeLanguageStartState.bind(placementKey, button, variant)
        }
    }

    private fun big(elements: NativeAdElements, variant: Int) =
        NativeAdDesign.card(context).apply {
            when (variant) {
                1, 2, 4, 9 -> addView(media(elements), flexibleMediaParams())
                3 -> {
                    addView(elements.infoRow(meta = MetaStyle.NONE), match())
                    addView(gap())
                    addView(media(elements), flexibleMediaParams())
                }
                5, 6, 8 -> {
                    addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                    addView(gap())
                    addView(media(elements), flexibleMediaParams())
                }
                7 -> {
                    addView(elements.textColumn(showBody = false), match())
                    addView(gap())
                    addView(media(elements), flexibleMediaParams())
                }
            }
            addView(gap())
            when (variant) {
                1 -> {
                    addView(elements.infoRow(meta = MetaStyle.STARS), match())
                    addView(gap())
                    addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                }
                2 -> {
                    addView(elements.infoRow(meta = MetaStyle.STARS), match())
                    addView(gap())
                    addView(rightAlignedButton(elements), match(dp(NativeAdDesign.buttonHeight)))
                }
                3, 7 -> addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                4 -> {
                    addView(elements.infoRow(
                        badgeInTitle = false, meta = MetaStyle.BADGE,
                    ), match())
                    addView(gap())
                    addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                }
                5, 6 -> addView(elements.infoRow(
                    badgeInTitle = false, meta = MetaStyle.BADGE_STARS_FREE,
                    bodyBeforeMeta = variant == 6,
                ), match())
                8 -> addView(elements.textColumn(showBody = false), match())
                9 -> addView(titleAndButton(elements), match(dp(NativeAdDesign.buttonHeight)))
            }
        }

    private fun small(elements: NativeAdElements, variant: Int) =
        NativeAdDesign.card(context).apply {
            when (variant) {
                1 -> {
                    addView(elements.infoRow(meta = MetaStyle.STARS), match())
                    addView(gap())
                    addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                }
                2 -> {
                    addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                    addView(gap())
                    addView(elements.infoRow(
                        badgeInTitle = false, meta = MetaStyle.BADGE,
                    ), match())
                }
                3 -> addView(LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    addView(elements.icon(NativeAdDesign.iconLarge), LinearLayout.LayoutParams(
                        dp(NativeAdDesign.iconLarge), dp(NativeAdDesign.iconLarge),
                    ).apply { marginEnd = dp(NativeAdDesign.itemGap) })
                    addView(LinearLayout(context).apply {
                        orientation = LinearLayout.VERTICAL
                        addView(elements.textColumn(bodyLines = 2), match())
                        addView(gap())
                        addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                    }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                }, match())
                4 -> {
                    addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                    addView(gap())
                    addView(elements.infoRow(), match())
                }
            }
        }

    private fun tiny(elements: NativeAdElements, circle: Boolean) =
        NativeAdDesign.card(context).apply {
            addView(CtaWidthRow(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                addView(elements.icon(NativeAdDesign.iconSmall), LinearLayout.LayoutParams(
                    dp(NativeAdDesign.iconSmall), dp(NativeAdDesign.iconSmall),
                ).apply { marginEnd = dp(NativeAdDesign.itemGap) })
                addView(elements.textColumn(
                    meta = MetaStyle.NONE, bodyLines = if (circle) 1 else 2,
                ), LinearLayout.LayoutParams(
                    0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f,
                ))
                val button = elements.cta(circle)
                constrainedCta = button as? TextView
                addView(button, LinearLayout.LayoutParams(
                    if (circle) dp(48) else ViewGroup.LayoutParams.WRAP_CONTENT,
                    dp(NativeAdDesign.buttonHeight),
                ).apply { marginStart = dp(NativeAdDesign.itemGap) })
            }, match(dp(if (circle) 48 else 54)))
        }

    private fun collapsible(elements: NativeAdElements, variant: Int) =
        NativeAdDesign.card(context).apply {
            // The Flutter AdsCollapsibleNative widget owns the collapse interaction.
            addView(View(context), match(dp(28)))
            addView(gap())
            if (variant == 2) {
                addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
                addView(gap())
            }
            addView(media(elements), flexibleMediaParams())
            addView(gap())
            if (variant == 2) addView(elements.infoRow(
                badgeInTitle = false, meta = MetaStyle.BADGE_STARS_FREE,
            ), match())
            else addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
        }

    // Collap1 has its own layout entry. Its current Figma geometry matches Big4.
    private fun collap1Expanded(elements: NativeAdElements) =
        NativeAdDesign.card(context).apply {
            addView(media(elements), flexibleMediaParams())
            addView(gap())
            addView(elements.infoRow(
                badgeInTitle = false,
                meta = MetaStyle.BADGE,
            ), match())
            addView(gap())
            addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
        }

    private fun collap1Collapsed(elements: NativeAdElements) = tiny(elements, circle = false)
    private fun collap2Collapsed(elements: NativeAdElements) = tiny(elements, circle = true)
    private fun collap3Collapsed(elements: NativeAdElements) = tiny(elements, circle = false)

    private fun full(elements: NativeAdElements, variant: Int) =
        NativeAdDesign.card(
            context,
            dark = variant == 2 || variant == 4,
            padded = false,
            fullScreen = true,
        ).apply {
            val mediaArea = FrameLayout(context)
            val media = elements.media()
            when (variant) {
                1, 5 -> mediaArea.addView(media, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(412), Gravity.CENTER,
                ))
                2 -> mediaArea.addView(media, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                ))
                else -> mediaArea.addView(media, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    dp(232), Gravity.CENTER,
                ))
            }
            if (variant in 2..4) mediaArea.addView(
                NativeAdDesign.badge(context), FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    dp(NativeAdDesign.badgeHeight),
                    Gravity.TOP or Gravity.START,
                ).apply { setMargins(dp(12), dp(12), 0, 0) },
            )
            addView(mediaArea, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f,
            ))
            addView(LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                val padding = dp(16)
                setPadding(padding, padding, padding, padding)
                val info = elements.infoRow(
                    meta = if (variant == 1 || variant == 5) MetaStyle.STARS
                           else MetaStyle.NONE,
                    badgeInTitle = variant == 1 || variant == 5,
                ).apply { minimumHeight = dp(if (variant == 1 || variant == 5) 56 else 48) }
                addView(info, match())
                addView(gap(12))
                addView(elements.cta(), match(dp(NativeAdDesign.buttonHeight)))
            }, match(dp(if (variant == 1 || variant == 5) 148 else 140)))
        }

    private fun card(elements: NativeAdElements) =
        NativeAdDesign.card(context).apply {
            addView(elements.media(), match(dp(NativeAdDesign.cardMediaHeight)))
            addView(gap())
            addView(titleAndButton(elements), match(dp(NativeAdDesign.buttonHeight)))
        }

    private fun rightAlignedButton(elements: NativeAdElements) =
        CtaWidthRow(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END
            val button = elements.cta()
            constrainedCta = button as? TextView
            addView(button, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, dp(NativeAdDesign.buttonHeight),
            ))
        }

    private fun titleAndButton(elements: NativeAdElements) =
        CtaWidthRow(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            addView(elements.textColumn(showBody = false), LinearLayout.LayoutParams(
                0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f,
            ))
            val button = elements.cta()
            constrainedCta = button as? TextView
            addView(button, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, dp(NativeAdDesign.buttonHeight),
            ).apply { marginStart = dp(NativeAdDesign.itemGap) })
        }
}

private class CtaWidthRow(context: Context) : LinearLayout(context) {
    var constrainedCta: TextView? = null

    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if (MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED) {
            constrainedCta?.maxWidth = MeasureSpec.getSize(widthMeasureSpec) / 3
        }
        super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }
}

private class RatioMedia(context: Context) : FrameLayout(context) {
    override fun onMeasure(widthMeasureSpec: Int, heightMeasureSpec: Int) {
        if (MeasureSpec.getMode(heightMeasureSpec) == MeasureSpec.EXACTLY) {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec)
            return
        }
        val width = MeasureSpec.getSize(widthMeasureSpec)
        val height = kotlin.math.ceil(width * 9.0 / 16.0).toInt()
        super.onMeasure(
            widthMeasureSpec,
            MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY),
        )
    }
}

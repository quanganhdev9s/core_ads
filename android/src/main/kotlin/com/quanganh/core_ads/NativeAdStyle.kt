package com.quanganh.core_ads

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.View
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAdView
import kotlin.math.roundToInt

/** Keys shared by Remote Config style values and the Flutter native factory option. */
internal object NativeAdStyleKeys {
    const val ctaBackground = "cta_bg"
    const val ctaText = "cta_text"
    const val ctaCornerDp = "cta_corner_dp"
    const val cardBackground = "card_bg"
    const val cardCornerDp = "card_corner_dp"
    const val cardStroke = "card_stroke"
    const val cardStrokeDp = "card_stroke_dp"
    const val titleColor = "title_color"
    const val bodyColor = "body_color"
    const val ctaHeightDp = "cta_height_dp"
    const val ctaTextSp = "cta_text_sp"
    const val titleTextSp = "title_text_sp"
    const val bodyTextSp = "body_text_sp"
    const val mediaHeightDp = "media_height_dp"
    const val iconSizeDp = "icon_size_dp"
    const val cardPaddingDp = "card_padding_dp"

    const val factoryOption = "nativeStyle"
}

/** Applies supplied ad_templates fields while retaining the base layout's other values. */
internal class NativeAdStyle(private val values: Map<*, *>) {
    companion object {
        fun fromOptions(value: Any?): NativeAdStyle? =
            (value as? Map<*, *>)?.takeIf { it.isNotEmpty() }?.let(::NativeAdStyle)
    }

    private fun color(key: String): Int? = (values[key] as? String)?.let {
        runCatching { Color.parseColor(it) }.getOrNull()
    }

    private fun number(key: String): Float? = (values[key] as? Number)?.toFloat()

    private fun dp(context: Context, value: Float): Int =
        (value * context.resources.displayMetrics.density).roundToInt()

    fun apply(context: Context, root: NativeAdView, template: NativeAdTemplate) {
        val fullScreen = template.name.startsWith("Full")
        val dark = template == NativeAdTemplate.Full2 || template == NativeAdTemplate.Full4
        val card = root.getChildAt(0)
        if (card != null) {
            (card.background?.mutate() as? GradientDrawable)?.let { background ->
                color(NativeAdStyleKeys.cardBackground)?.let(background::setColor)
                number(NativeAdStyleKeys.cardCornerDp)?.let {
                    background.cornerRadius = dp(context, it).toFloat()
                    card.clipToOutline = true
                }
                val strokeColor = color(NativeAdStyleKeys.cardStroke)
                val strokeWidth = number(NativeAdStyleKeys.cardStrokeDp)
                if (strokeColor != null || strokeWidth != null && !fullScreen && !dark) {
                    background.setStroke(
                        dp(context, strokeWidth ?: 1f),
                        strokeColor ?: NativeAdDesign.outline,
                    )
                }
            }
            number(NativeAdStyleKeys.cardPaddingDp)?.let {
                val padding = dp(context, it)
                card.setPadding(padding, padding, padding, padding)
            }
        }

        // MediaView uses FIT_CENTER on the dark Full layouts. Match its unused
        // space to the overridden card background so no seam appears.
        if (dark) {
            color(NativeAdStyleKeys.cardBackground)?.let { color ->
                (root.mediaView?.background?.mutate() as? GradientDrawable)?.setColor(color)
            }
        }

        root.callToActionView?.let { cta ->
            (cta.background?.mutate() as? GradientDrawable)?.let { background ->
                color(NativeAdStyleKeys.ctaBackground)?.let(background::setColor)
                number(NativeAdStyleKeys.ctaCornerDp)?.let {
                    background.cornerRadius = dp(context, it).toFloat()
                }
            }
            (cta as? TextView)?.let { text ->
                color(NativeAdStyleKeys.ctaText)?.let(text::setTextColor)
                number(NativeAdStyleKeys.ctaTextSp)?.let {
                    text.setTextSize(TypedValue.COMPLEX_UNIT_SP, it)
                }
            }
            number(NativeAdStyleKeys.ctaHeightDp)?.let { height ->
                val previousHeight = cta.layoutParams?.height
                val nextHeight = dp(context, height)
                cta.layoutParams?.let { params ->
                    params.height = nextHeight
                    if (cta is FrameLayout) params.width = nextHeight
                    cta.layoutParams = params
                }
                // CTA rows in Big2/Tiny and the Full footer have fixed heights.
                // Grow their container only when this override changes the CTA.
                if (previousHeight != null && previousHeight > 0) {
                    val parent = cta.parent as? View
                    parent?.layoutParams?.let { params ->
                        if (params.height == previousHeight || fullScreen) {
                            params.height += nextHeight - previousHeight
                            parent.layoutParams = params
                        }
                    }
                }
            }
        }
        (root.headlineView as? TextView)?.let { title ->
            color(NativeAdStyleKeys.titleColor)?.let(title::setTextColor)
            number(NativeAdStyleKeys.titleTextSp)?.let {
                title.setTextSize(TypedValue.COMPLEX_UNIT_SP, it)
            }
        }
        (root.bodyView as? TextView)?.let { body ->
            color(NativeAdStyleKeys.bodyColor)?.let(body::setTextColor)
            number(NativeAdStyleKeys.bodyTextSp)?.let {
                body.setTextSize(TypedValue.COMPLEX_UNIT_SP, it)
            }
        }
        (root.iconView as? ImageView)?.let { icon ->
            number(NativeAdStyleKeys.iconSizeDp)?.let { size ->
                icon.layoutParams?.let { params ->
                    params.width = dp(context, size)
                    params.height = params.width
                    icon.layoutParams = params
                }
            }
        }
        if (!fullScreen) root.mediaView?.let { media ->
            number(NativeAdStyleKeys.mediaHeightDp)?.let { height ->
                val parent = media.parent
                val target = if (parent is FrameLayout && parent.childCount == 1) parent else media
                target.layoutParams?.let { params ->
                    params.height = dp(context, height)
                    if (params is LinearLayout.LayoutParams) params.weight = 0f
                    target.layoutParams = params
                }
            }
        }
    }
}

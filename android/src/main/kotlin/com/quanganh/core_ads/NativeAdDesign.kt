package com.quanganh.core_ads

import android.content.Context
import android.graphics.Outline
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewOutlineProvider
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.widget.TextViewCompat
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import kotlin.math.roundToInt

/** Values shared by the Android layouts in the WaveZ native ad design. */
internal object NativeAdDesign {
    const val white = 0xFFFFFFFF.toInt()
    const val outline = 0xFFEBEBEB.toInt()
    const val title = 0xFF202020.toInt()
    const val body = 0xFF585858.toInt()
    const val darkBackground = 0xFF1B1B1B.toInt()
    const val darkTitle = 0xFFFBFBFB.toInt()
    const val darkBody = 0xFFCACACA.toInt()
    const val cta = 0xFF017FE6.toInt()
    const val languageStartUnselectedCta = 0xFF7E2D96.toInt()
    const val badge = 0xFFF8C600.toInt()

    const val cardRadius = 12
    const val cardPadding = 12
    const val borderWidth = 1
    const val itemGap = 8
    const val iconMedium = 48
    const val iconSmall = 40
    const val iconLarge = 96
    const val buttonHeight = 48
    const val tiny2Height = 74
    const val buttonRadius = 24
    const val mediaRadius = 8
    const val cardMediaHeight = 158
    const val badgeRadius = 4
    const val badgeHeight = 16
    const val titleSize = 14f
    const val bodySize = 12f
    const val ctaSize = 14f
    const val badgeSize = 10f
    const val titleLineHeight = 20
    const val bodyLineHeight = 16
    const val ctaLineHeight = 20
    const val ctaPaddingHorizontal = 16

    fun dp(context: Context, value: Int): Int =
        (value * context.resources.displayMetrics.density).roundToInt()

    fun background(context: Context, color: Int, radius: Int, stroke: Int? = null) =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(context, radius).toFloat()
            if (stroke != null) setStroke(dp(context, borderWidth), stroke)
        }

    private fun roundedOutline(context: Context, radius: Int) = object : ViewOutlineProvider() {
        override fun getOutline(view: View, outline: Outline) {
            outline.setRoundRect(0, 0, view.width, view.height, dp(context, radius).toFloat())
        }
    }

    fun card(
        context: Context,
        dark: Boolean = false,
        padded: Boolean = true,
        fullScreen: Boolean = false,
    ) =
        LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            background = background(
                context,
                if (dark) darkBackground else white,
                if (fullScreen) 0 else cardRadius,
                if (fullScreen || dark) null else outline,
            )
            clipToOutline = !fullScreen
            if (padded) {
                val inset = dp(context, cardPadding + borderWidth)
                setPadding(inset, inset, inset, inset)
            }
        }

    fun text(
        context: Context,
        size: Float,
        weight: Int,
        color: Int,
        lines: Int = 1,
    ) = TextView(context).apply {
        includeFontPadding = false
        setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
        typeface = Typeface.create(
            if (weight >= 500) "sans-serif-medium" else "sans-serif",
            Typeface.NORMAL,
        )
        setTextColor(color)
        maxLines = lines
        ellipsize = TextUtils.TruncateAt.END
    }

    fun badge(context: Context) = text(context, badgeSize, 500, white).apply {
        text = "Ad"
        gravity = Gravity.CENTER
        background = background(context, badge, badgeRadius)
        setPadding(dp(context, 4), 0, dp(context, 4), 0)
    }

    fun icon(context: Context, size: Int) = ImageView(context).apply {
        scaleType = ImageView.ScaleType.CENTER_CROP
        outlineProvider = roundedOutline(context, if (size == iconLarge) 16 else mediaRadius)
        clipToOutline = true
        contentDescription = null
    }

    fun media(context: Context) =
        MediaView(context).apply {
            outlineProvider = roundedOutline(context, mediaRadius)
            clipToOutline = true
            setImageScaleType(ImageView.ScaleType.FIT_CENTER)
        }

    fun button(context: Context, label: String?) = text(
        context, ctaSize, 500, white,
    ).apply {
        text = label.orEmpty()
        gravity = Gravity.CENTER
        TextViewCompat.setLineHeight(this, dp(context, ctaLineHeight))
        setPadding(
            dp(context, ctaPaddingHorizontal), 0,
            dp(context, ctaPaddingHorizontal), 0,
        )
        background = background(context, cta, buttonRadius)
        visibility = if (label.isNullOrBlank()) View.GONE else View.VISIBLE
    }

    fun circleButton(context: Context, label: String?) = FrameLayout(context).apply {
        background = background(context, cta, buttonRadius)
        visibility = if (label.isNullOrBlank()) View.GONE else View.VISIBLE
        contentDescription = label
        addView(ImageView(context).apply {
            setImageResource(R.drawable.core_ads_ad_arrow)
            contentDescription = null
        }, FrameLayout.LayoutParams(
            dp(context, 16), dp(context, 16), Gravity.CENTER,
        ))
    }
}

/** Views are created once, composed by a layout, and registered with NativeAdView. */
internal class NativeAdElements(
    private val context: Context,
    private val ad: NativeAd,
    private val dark: Boolean,
) {
    val headline = NativeAdDesign.text(
        context, NativeAdDesign.titleSize, 500,
        if (dark) NativeAdDesign.darkTitle else NativeAdDesign.title,
    ).apply { text = ad.headline }
    val body = NativeAdDesign.text(
        context, NativeAdDesign.bodySize, 400,
        if (dark) NativeAdDesign.darkBody else NativeAdDesign.body,
        lines = 2,
    ).apply {
        text = ad.body.orEmpty()
        visibility = if (ad.body.isNullOrBlank()) View.GONE else View.VISIBLE
    }
    private var iconView: ImageView? = null
    private var mediaView: MediaView? = null
    private var ctaView: View? = null
    private var ratingView: View? = null

    fun icon(size: Int = NativeAdDesign.iconMedium): ImageView =
        NativeAdDesign.icon(context, size).also {
            iconView = it
            val drawable = ad.icon?.drawable
            if (drawable == null) it.visibility = View.GONE else it.setImageDrawable(drawable)
        }

    fun media(): MediaView =
        NativeAdDesign.media(context).also {
            mediaView = it
            it.mediaContent = ad.mediaContent
            if (ad.mediaContent == null) it.visibility = View.GONE
        }

    fun cta(circle: Boolean = false): View =
        (if (circle) NativeAdDesign.circleButton(context, ad.callToAction)
         else NativeAdDesign.button(context, ad.callToAction)).also { ctaView = it }

    fun textColumn(
        badgeInTitle: Boolean = true,
        meta: MetaStyle = MetaStyle.NONE,
        showBody: Boolean = true,
        bodyLines: Int = 1,
        bodyBeforeMeta: Boolean = false,
    ) = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        body.maxLines = bodyLines
        addView(LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            if (badgeInTitle) addView(
                NativeAdDesign.badge(context),
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    NativeAdDesign.dp(context, NativeAdDesign.badgeHeight),
                ).apply { marginEnd = NativeAdDesign.dp(context, 4) },
            )
            addView(headline, LinearLayout.LayoutParams(
                0, NativeAdDesign.dp(context, NativeAdDesign.titleLineHeight), 1f,
            ))
        }, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            NativeAdDesign.dp(context, NativeAdDesign.titleLineHeight),
        ))
        fun addMeta() {
            addView(metaRow(meta), LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                NativeAdDesign.dp(context, if (meta == MetaStyle.STARS) 14 else 16),
            ).apply { topMargin = NativeAdDesign.dp(context, 2) })
        }
        fun addBody() {
            addView(body, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                NativeAdDesign.dp(context, NativeAdDesign.bodyLineHeight * bodyLines),
            ).apply { topMargin = NativeAdDesign.dp(context, 2) })
        }
        if (bodyBeforeMeta && showBody) addBody()
        if (meta != MetaStyle.NONE) addMeta()
        if (!bodyBeforeMeta && showBody) addBody()
    }

    fun infoRow(
        iconSize: Int = NativeAdDesign.iconMedium,
        badgeInTitle: Boolean = true,
        meta: MetaStyle = MetaStyle.NONE,
        showBody: Boolean = true,
        bodyLines: Int = 1,
        bodyBeforeMeta: Boolean = false,
    ) = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.TOP
        addView(icon(iconSize), LinearLayout.LayoutParams(
            NativeAdDesign.dp(context, iconSize), NativeAdDesign.dp(context, iconSize),
        ).apply { marginEnd = NativeAdDesign.dp(context, NativeAdDesign.itemGap) })
        addView(textColumn(badgeInTitle, meta, showBody, bodyLines, bodyBeforeMeta), LinearLayout.LayoutParams(
            0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f,
        ))
    }

    private fun metaRow(style: MetaStyle) = LinearLayout(context).apply {
        orientation = LinearLayout.HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        if (style == MetaStyle.BADGE || style == MetaStyle.BADGE_STARS_FREE) {
            addView(NativeAdDesign.badge(context), LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                NativeAdDesign.dp(context, NativeAdDesign.badgeHeight),
            ).apply { marginEnd = NativeAdDesign.dp(context, 6) })
        }
        if (style == MetaStyle.STARS || style == MetaStyle.BADGE_STARS_FREE) {
            val rating = ad.starRating
            val stars = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                val count = rating?.roundToInt()?.coerceIn(0, 5) ?: 0
                visibility = if (count == 0) View.GONE else View.VISIBLE
                repeat(count) {
                    addView(ImageView(context).apply {
                        setImageResource(R.drawable.core_ads_ad_star)
                        contentDescription = null
                    }, LinearLayout.LayoutParams(
                        NativeAdDesign.dp(context, 14),
                        NativeAdDesign.dp(context, 14),
                    ))
                }
            }
            ratingView = stars
            addView(stars)
        }
        if (style == MetaStyle.BADGE_STARS_FREE) {
            addView(NativeAdDesign.text(
                context, NativeAdDesign.badgeSize, 500,
                if (dark) NativeAdDesign.darkBody else NativeAdDesign.body,
            ).apply { text = "FREE" }, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            ).apply { marginStart = NativeAdDesign.dp(context, 6) })
        }
    }

    fun bind(root: NativeAdView) {
        root.headlineView = headline
        root.bodyView = body.takeIf { it.parent != null }
        root.iconView = iconView
        root.mediaView = mediaView
        root.callToActionView = ctaView
        root.starRatingView = ratingView
        root.setNativeAd(ad)
    }
}

internal enum class MetaStyle { NONE, STARS, BADGE, BADGE_STARS_FREE }

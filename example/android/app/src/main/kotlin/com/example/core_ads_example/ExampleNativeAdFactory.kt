package com.example.core_ads_example

import android.content.Context
import android.graphics.Typeface
import android.text.TextUtils
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.NativeAdFactory

class ExampleNativeAdFactory(
    private val context: Context,
) : NativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = NativeAdView(context).apply {
            clipToPadding = true
            clipChildren = true
        }
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(20, 12, 20, 12)
            clipToPadding = true
            clipChildren = true
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        val sponsored = TextView(context).apply {
            text = "Sponsored"
            textSize = 11f
            isSingleLine = true
            maxLines = 1
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        val headline = TextView(context).apply {
            textSize = 16f
            setTypeface(typeface, Typeface.BOLD)
            isSingleLine = true
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        val body = TextView(context).apply {
            textSize = 13f
            isSingleLine = true
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }
        val callToAction = Button(context).apply {
            minHeight = 0
            minimumHeight = 0
            isSingleLine = true
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT,
            )
        }

        container.addView(sponsored)
        container.addView(headline)
        container.addView(body)
        container.addView(callToAction)
        adView.addView(container)

        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = callToAction

        headline.text = nativeAd.headline

        if (nativeAd.body == null) {
            body.visibility = View.GONE
        } else {
            body.text = nativeAd.body
            body.visibility = View.VISIBLE
        }

        if (nativeAd.callToAction == null) {
            callToAction.visibility = View.GONE
        } else {
            callToAction.text = nativeAd.callToAction
            callToAction.visibility = View.VISIBLE
        }

        adView.setNativeAd(nativeAd)
        return adView
    }
}

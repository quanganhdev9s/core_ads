package com.quanganh.core_ads

import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import java.lang.ref.WeakReference

/** Rebinds another layout to the same loaded NativeAd without requesting a new ad. */
internal object NativeCollapsibleState {
    private data class Desired(val collapsed: Boolean, val collapsedFactoryId: String?)

    private class Binding(
        view: NativeAdView,
        ad: NativeAd,
        val expandedTemplate: NativeAdTemplate,
        val layouts: NativeAdLayouts,
        val style: NativeAdStyle?,
    ) {
        val view = WeakReference(view)
        val ad = ad
        var currentTemplate = expandedTemplate
    }

    private val desiredByPlacement = mutableMapOf<String, Desired>()
    private val bindingsByPlacement = mutableMapOf<String, Binding>()

    fun bind(
        placementKey: String,
        view: NativeAdView,
        ad: NativeAd,
        template: NativeAdTemplate,
        layouts: NativeAdLayouts,
        style: NativeAdStyle?,
    ) {
        val binding = Binding(view, ad, template, layouts, style)
        bindingsByPlacement[placementKey] = binding
        desiredByPlacement[placementKey]?.let { apply(placementKey, binding, it) }
    }

    fun setCollapsed(placementKey: String, collapsed: Boolean, collapsedFactoryId: String?) {
        val desired = Desired(collapsed, collapsedFactoryId)
        desiredByPlacement[placementKey] = desired
        val binding = bindingsByPlacement[placementKey] ?: return
        if (binding.view.get() == null) bindingsByPlacement.remove(placementKey)
        else apply(placementKey, binding, desired)
    }

    fun clear(placementKey: String) {
        desiredByPlacement.remove(placementKey)
        bindingsByPlacement.remove(placementKey)
    }

    fun clearAll() {
        desiredByPlacement.clear()
        bindingsByPlacement.clear()
    }

    private fun apply(placementKey: String, binding: Binding, desired: Desired) {
        val template = if (desired.collapsed) {
            NativeAdTemplate.entries.firstOrNull { it.factoryId == desired.collapsedFactoryId }
                ?: NativeAdTemplate.Small1
        } else binding.expandedTemplate
        if (template == binding.currentTemplate) return
        val view = binding.view.get() ?: return
        binding.layouts.render(view, template, binding.ad, placementKey, binding.style)
        binding.currentTemplate = template
    }
}

package com.quanganh.core_ads

import android.view.Gravity
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import java.lang.ref.WeakReference

/** Updates the registered CTA asset in place, so selecting a language does not reload the ad. */
internal object NativeLanguageStartState {
    private data class Binding(val button: WeakReference<TextView>, val variant: Int)

    private val selectedByPlacement = mutableMapOf<String, Boolean>()
    private val buttonsByPlacement = mutableMapOf<String, MutableList<Binding>>()

    fun bind(placementKey: String, button: TextView, variant: Int) {
        buttonsByPlacement.getOrPut(placementKey) { mutableListOf() }
            .add(Binding(WeakReference(button), variant))
        update(button, variant, selectedByPlacement[placementKey] == true)
    }

    fun setSelected(placementKey: String, selected: Boolean) {
        selectedByPlacement[placementKey] = selected
        val buttons = buttonsByPlacement[placementKey] ?: return
        buttons.removeAll { binding ->
            val button = binding.button.get() ?: return@removeAll true
            update(button, binding.variant, selected)
            false
        }
    }

    fun clear(placementKey: String) {
        setSelected(placementKey, false)
        selectedByPlacement.remove(placementKey)
    }

    fun clearAll() {
        selectedByPlacement.clear()
        buttonsByPlacement.clear()
    }

    private fun update(button: TextView, variant: Int, selected: Boolean) {
        val context = button.context
        if (variant == 1) {
            val params = button.layoutParams as? FrameLayout.LayoutParams ?: return
            params.width = if (selected) NativeAdDesign.dp(context, 96)
                else ViewGroup.LayoutParams.MATCH_PARENT
            params.height = NativeAdDesign.dp(
                context,
                if (selected) 40 else NativeAdDesign.buttonHeight,
            )
            params.gravity = Gravity.END or Gravity.CENTER_VERTICAL
            button.layoutParams = params
        } else {
            button.background = NativeAdDesign.background(
                context,
                if (selected) NativeAdDesign.cta else NativeAdDesign.languageStartUnselectedCta,
                NativeAdDesign.buttonRadius,
            )
        }
    }
}

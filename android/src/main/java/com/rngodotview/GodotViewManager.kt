package com.rngodotview

import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.SimpleViewManager
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp

class GodotViewManager(private val reactContext: ReactApplicationContext)
    : SimpleViewManager<GodotView>() {

    override fun getName() = "GodotView"

    override fun createViewInstance(context: ThemedReactContext): GodotView =
        GodotView(context)

    override fun getExportedCustomDirectEventTypeConstants(): MutableMap<String, Any> =
      hashMapOf("onGodotEvent" to hashMapOf("registrationName" to "onGodotEvent"))


    @ReactProp(name = "pckName")
    fun setPckName(view: GodotView, pckName: String?) {
        view.setPckName(pckName)
    }
}

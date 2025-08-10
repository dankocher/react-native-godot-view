package com.rngodotview

import com.facebook.react.ReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager

class GodotBridgePackage : ReactPackage {
    override fun createNativeModules(reactContext: ReactApplicationContext)
        = listOf<NativeModule>(GodotBridgeModule(reactContext))

    override fun createViewManagers(reactContext: ReactApplicationContext)
        = emptyList<ViewManager<*, *>>()
}

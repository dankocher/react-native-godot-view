package com.rngodotview
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod
class GodotBridgeModule(ctx: ReactApplicationContext): ReactContextBaseJavaModule(ctx) {
  override fun getName() = "GodotBridge"
  @ReactMethod fun send(json:String) { RnBridgePlugin.instance?.receive_from_rn(json) }
}

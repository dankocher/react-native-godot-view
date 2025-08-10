package com.rngodotview
import android.util.Log
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
class RnBridgePlugin(godot: Godot): GodotPlugin(godot) {
  companion object { var instance: RnBridgePlugin? = null }
  override fun getPluginName() = "RNBridge"
  override fun getPluginSignals() = setOf(SignalInfo("event_from_rn", String::class.java))
  init { instance = this; Log.d("RNBridge","Plugin created") }
  @UsedByGodot fun send_to_rn(json:String) { Log.d("RNBridge","Godot→RN $json"); RnBridge.listener?.invoke(json) }
  fun receive_from_rn(json:String) { Log.d("RNBridge","RN→Godot $json"); emitSignal("event_from_rn", json) }
}

package com.rngodotview

import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.godotengine.godot.plugin.SignalInfo
import com.rngodot.godotview.RnBridge

class RnBridgePlugin(godot: Godot) : GodotPlugin(godot) {

    companion object { var instance: RnBridgePlugin? = null }

    override fun getPluginName() = "RNBridge"

    override fun getPluginSignals() = setOf(
        SignalInfo("event_from_rn", String::class.java) // RN → Godot (emitido aquí)
    )

    init { instance = this }

    // Llamable desde GDScript: envía eventos a RN
    @UsedByGodot
    fun send_to_rn(json: String) {
        RnBridge.listener?.invoke(json)
    }

    // Llamable desde Java/Kotlin (RN): envía eventos a Godot
    fun receive_from_rn(json: String) {
        emitSignal("event_from_rn", json)
    }
}

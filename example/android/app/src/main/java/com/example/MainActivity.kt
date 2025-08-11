package com.example


// ✅ ADD: Android/Godot imports required for embedding the engine
import android.app.Activity
import android.os.Bundle
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotHost
import com.rngodotview.RnBridgePlugin

import com.facebook.react.ReactActivity
import com.facebook.react.ReactActivityDelegate
import com.facebook.react.defaults.DefaultNewArchitectureEntryPoint.fabricEnabled
import com.facebook.react.defaults.DefaultReactActivityDelegate

// ✅ IMPORTANT: Implement GodotHost to embed Godot into your RN Activity
class MainActivity : ReactActivity(), GodotHost {

  // ✅ IMPORTANT: Keep a single engine instance for the entire Activity lifecycle
  private lateinit var godot: Godot

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    // ✅ IMPORTANT: Create the engine instance only once
    // TIP: If you need arguments, pass them here (e.g., display driver flags)
    godot = Godot(this)
  }

  override fun getMainComponentName(): String = "RNGodotExample"
  override fun createReactActivityDelegate(): ReactActivityDelegate =
    DefaultReactActivityDelegate(this, mainComponentName, fabricEnabled)

  // ✅ REQUIRED by GodotHost: provide Activity and engine reference
  override fun getActivity(): Activity? = this
  override fun getGodot(): Godot = godot

  // ✅ REQUIRED: Ensure the .pck path matches your asset name and location
  // NOTE: The library auto-copies the first *.pck from src/assets/ into Android assets
  // If your file is named `mygame.pck`, update the line below to "res://mygame.pck"
  override fun getCommandLine(): MutableList<String> =
    mutableListOf("--main-pack", "res://game.pck")

  // ✅ REQUIRED: Register your RN ↔ Godot bridge plugin
  override fun getHostPlugins(engine: Godot) = setOf(RnBridgePlugin(engine))
}

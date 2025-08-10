package com.rngodotview

import android.content.Context
import android.util.AttributeSet
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.events.RCTEventEmitter
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import org.godotengine.godot.GodotFragment

object RnBridge { var listener: ((String) -> Unit)? = null }

class GodotView @JvmOverloads constructor(
  context: Context, attrs: AttributeSet? = null
) : FrameLayout(context, attrs) {

  private val reactContext = context as ReactContext
  private val fragmentTag = "RN_GODOT_FRAGMENT"
  private var pckName: String = "game.pck"

  init { if (id == View.NO_ID) id = View.generateViewId() }

  fun setPckName(name: String?) { pckName = name ?: "game.pck" }

  private val hostActivity: FragmentActivity?
    get() = reactContext.currentActivity as? FragmentActivity

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    val host = hostActivity ?: return

    // Monta el GodotFragment SIN arguments (tomará args de GodotHost en MainActivity)
    val fm = host.supportFragmentManager
    if (fm.findFragmentByTag(fragmentTag) == null) {
      // Asegúrate de que el View ya está en el árbol (evita timing issues)
      post {
        if (fm.findFragmentByTag(fragmentTag) == null) {
          val frag = GodotFragment()
          fm.beginTransaction()
            .replace(this@GodotView.id, frag, fragmentTag)
            .commitAllowingStateLoss()
        }
      }
    }

    // Puente Godot → RN
    RnBridge.listener = { payload ->
      val event: WritableMap = Arguments.createMap().apply { putString("data", payload) }
      reactContext.getJSModule(RCTEventEmitter::class.java)
        .receiveEvent(this.id, "onGodotEvent", event)
    }
  }

  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    val host = hostActivity ?: return
    val fm = host.supportFragmentManager
    fm.findFragmentByTag(fragmentTag)?.let {
      fm.beginTransaction().remove(it).commitAllowingStateLoss()
    }
    RnBridge.listener = null
  }
}

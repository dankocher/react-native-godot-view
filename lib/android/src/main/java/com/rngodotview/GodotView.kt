package com.rngodotview
import android.content.Context
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReactContext
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.RCTEventEmitter
import org.godotengine.godot.GodotFragment

object RnBridge { var listener: ((String) -> Unit)? = null }

class GodotView(context: Context): FrameLayout(context) {
  private val reactContext = context as ReactContext
  private val tag = "RN_GODOT_FRAGMENT"
  init { if (id == View.NO_ID) id = View.generateViewId() }
  fun setPckName(name:String?) { /* optional; GodotHost decides */ }
  private val host: FragmentActivity? get() = reactContext.currentActivity as? FragmentActivity
  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    val h = host ?: return
    val fm = h.supportFragmentManager
    if (fm.findFragmentByTag(tag) == null) {
      post {
        if (fm.findFragmentByTag(tag) == null) {
          val frag = GodotFragment()
          fm.beginTransaction().replace(this.id, frag, tag).commitAllowingStateLoss()
        }
      }
    }
    RnBridge.listener = { payload ->
      val event: WritableMap = Arguments.createMap().apply { putString("data", payload) }
      reactContext.getJSModule(RCTEventEmitter::class.java).receiveEvent(this.id, "onGodotEvent", event)
    }
  }
  override fun onDetachedFromWindow() {
    super.onDetachedFromWindow()
    val h = host ?: return
    val fm = h.supportFragmentManager
    fm.findFragmentByTag(tag)?.let { fm.beginTransaction().remove(it).commitAllowingStateLoss() }
    RnBridge.listener = null
  }
}

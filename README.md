# react-native-godot-view

Embed a **Godot** game inside a **React Native** view (Android & iOS) with a simple **event bridge** (RN ⇄ Godot).  
The library also **copies your `.pck` automatically** from your RN project (`src/assets/*.pck`) into each platform at build time.

Works with **React Native New Architecture (Fabric)**.

---

## Requirements

- React Native ≥ 0.73 (Fabric OK)
- Android: Gradle 8+, Android Gradle Plugin 8+, minSdk 24+
- iOS: Xcode 15+, iOS 13+, **real device** (Godot doesn’t run in the iOS simulator)
- You have an exported **Godot pack** (`.pck`) for your game

---

## Quick start

```bash
# 1) Install
npm i react-native-godot-view
# or
yarn add react-native-godot-view

# 2) iOS pods
cd ios && pod install
```

Place your Godot pack (any name) in your RN app at:

```
PROJECT_ROOT/src/assets/<your-pack>.pck
```

> On build, the library auto-copies the first `*.pck` it finds in `src/assets/`:
> - to **Android** → `android/app/src/main/assets/`
> - to **iOS** → app bundle (Copy Resources phase)

---

## Android setup

The library is autolinked and adds a Gradle task to copy the `.pck`.  
To **embed** Godot in a RN screen (recommended), add `GodotHost` to your `MainActivity`.

### 1) `MainActivity` (embed view)

`android/app/src/main/java/<yourpkg>/MainActivity.kt`:

```kotlin
package com.yourapp

// ✅ ADD: Android/Godot imports required for embedding the engine
import android.app.Activity
import android.os.Bundle
import org.godotengine.godot.Godot
import org.godotengine.godot.GodotHost
import com.rngodotview.RnBridgePlugin

// React Native imports
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

  // ✅ EDIT HERE: Replace with your actual RN component name (AppRegistry.registerComponent)
  override fun getMainComponentName(): String = "YourApp"

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


```

---

## iOS setup

We ship vendored `.xcframework`s via CocoaPods; no SPM needed.

```bash
cd ios
pod install
```

That’s it. The pod:
- Links **SwiftGodot** / **SwiftGodotKit**
- Adds `-lc++` & Swift stdlib embedding flags
- Copies the first `src/assets/*.pck` into your app bundle at build time

> iOS runs only on a **real device** for Godot content.

---

## Usage (JS/TS)

```tsx
import React from 'react';
import {View, Button} from 'react-native';
import {GodotView, GodotBridge} from 'react-native-godot-view';

export default function GameScreen() {
  return (
    <View style={{flex: 1}}>
      <GodotView
        style={{flex: 1}}
        onGodotEvent={(e) => {
          console.log('Godot → RN', e.nativeEvent?.data);
        }}
      />

      <Button
        title="Send to Godot"
        onPress={() =>
          GodotBridge.send(JSON.stringify({type: 'PING_FROM_RN', ts: Date.now()}))
        }
      />
    </View>
  );
}
```

---

## Godot side (GDScript)

```gdscript
func _ready():
    if Engine.has_singleton("RNBridge"):
        var rn = Engine.get_singleton("RNBridge")
        rn.connect("event_from_rn", Callable(self, "_on_event_from_rn"))
        rn.call("send_to_rn", JSON.stringify({"type":"PING_FROM_GODOT"}))
    else:
        print("RNBridge not available")

func _on_event_from_rn(json: String) -> void:
    print("RN → Godot: ", json)
```

---

## Props & API

### `<GodotView />` props

| Prop | Type | Default | Description |
|---|---|---|---|
| `pckName` | `string` | *(autodetect)* | Name of your pack in `src/assets/` |
| `onGodotEvent` | `(e: { nativeEvent: { data: string }}) => void` | — | Receives events from Godot |

### `GodotBridge` API

```ts
GodotBridge.send(json: string): void // RN → Godot
```

---

## How the .pck is detected & copied

- Put it in: `src/assets/<anyname>.pck`
- **Android**: copied to `android/app/src/main/assets/`
- **iOS**: copied to app bundle

---

## Troubleshooting

- Gray screen → check `.pck` copied
- `.pck missing` → verify `getCommandLine()` in `MainActivity`
- No events → ensure `getHostPlugins()` returns `RnBridgePlugin(engine)`
- iOS build errors → `pod install`, open `.xcworkspace`, build on device

---

## FAQ

**Multiple Godot views?**  
Not supported; Godot engine is singleton.

**App size?**  
~25–35 MB extra + your `.pck` size.

---

## License

See [LICENSE](./LICENSE) file for details.


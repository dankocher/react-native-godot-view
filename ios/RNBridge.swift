import SwiftGodot

// Centro de distribución hacia RN (closure lo setea RNGodotView)
final class BridgeCenter {
  static let shared = BridgeCenter()
  var toRN: ((String) -> Void)?
}

@Godot
final class RNBridge: GodotObject {
  @Signal var event_from_rn: SignalWithArguments<String>
  @Signal var event_from_godot: SignalWithArguments<String>

  // iOS → Godot (lo llamamos desde RN nativo)
  @Callable
  func receive_from_rn(_ json: String) {
    event_from_rn.emit(json)
  }

  // Godot → iOS (lo llama GDScript)
  @Callable
  func send_to_rn(_ json: String) {
    BridgeCenter.shared.toRN?(json)
  }
}

// Registra el singleton temprano cuando el engine sube
func setupBridge(level: GDExtension.InitializationLevel) {
  if level == .scene {
    register(type: RNBridge.self)
    registerSingleton(name: "RNBridge", instance: RNBridge())
  }
}

// Punto de entrada SwiftGodot (ata el hook)
#initSwiftExtension(cdecl: "swift_entry_point", types: [RNBridge.self], initHook: setupBridge)

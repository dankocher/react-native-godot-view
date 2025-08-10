import SwiftGodot
final class BridgeCenter { static let shared = BridgeCenter(); var toRN: ((String)->Void)? }
@Godot
final class RNBridge: GodotObject {
  @Signal var event_from_rn: SignalWithArguments<String>
  @Signal var event_from_godot: SignalWithArguments<String>
  @Callable func receive_from_rn(_ json: String) { event_from_rn.emit(json) }
  @Callable func send_to_rn(_ json: String) { BridgeCenter.shared.toRN?(json) }
}
func setupBridge(level: GDExtension.InitializationLevel) {
  if level == .scene {
    register(type: RNBridge.self)
    registerSingleton(name: "RNBridge", instance: RNBridge())
  }
}
#initSwiftExtension(cdecl: "swift_entry_point", types: [RNBridge.self], initHook: setupBridge)

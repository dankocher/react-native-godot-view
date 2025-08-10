@objc(GodotBridge)
final class GodotBridge: NSObject {
  @objc static func requiresMainQueueSetup() -> Bool { true }
  @objc func send(_ json: String) {
    // Busca el singleton registrado y llama el método SwiftGodot
    if let bridge = Engine.getSingleton(name: "RNBridge") as? RNBridge {
      bridge.receive_from_rn(json)
    }
  }
}

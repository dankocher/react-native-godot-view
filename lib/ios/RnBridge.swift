import Foundation

// Puente interno, simétrico al de Android.
// - Godot llamará a RnBridge.shared.sendToRN(json:)
// - RN llama a send(...) del módulo y esto envía a Godot con receiveFromRN(json:)
@objc(RnBridge)
class RnBridge: NSObject {
  static let shared = RnBridge()

  // Listener que la vista asigna para emitir eventos a JS
  var listener: ((String) -> Void)?

  // Godot → RN (llámalo desde tu integración de Godot en iOS)
  @objc func sendToRN(json: String) {
    NSLog("RNBridge Godot→RN \(json)")
    listener?(json)
  }

  // RN → Godot (impleméntalo para reenviar al engine Godot)
  func receiveFromRN(json: String) {
    NSLog("RNBridge RN→Godot \(json)")
    // TODO: reenvía al engine, p.ej. emitir señal/comando a tu plugin de Godot para iOS.
    // Ejemplos posibles según tu integración:
    // MyGodotPlugin.shared.emit(signal: "event_from_rn", payload: json)
    // o enviar por NotificationCenter si tu capa Godot lo observa.
  }
}

import Foundation

@objc(GodotBridge)
class GodotBridge: NSObject {
  @objc static func requiresMainQueueSetup() -> Bool { true }

  @objc func constantsToExport() -> [AnyHashable: Any]! { [:] }

  // RN → Godot
  @objc func send(_ json: String) {
    RnBridge.shared.receiveFromRN(json: json)
  }
}

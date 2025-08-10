import Foundation
import SwiftGodot
@objc(GodotBridge)
final class GodotBridge: NSObject {
  @objc static func requiresMainQueueSetup() -> Bool { true }
  @objc func send(_ json: String) {
    if let bridge = Engine.getSingleton(name: "RNBridge") as? RNBridge {
      bridge.receive_from_rn(json)
    }
  }
}

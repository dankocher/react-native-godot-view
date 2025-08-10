@objc(RNGodotViewManager)
final class RNGodotViewManager: RCTViewManager {
  override static func requiresMainQueueSetup() -> Bool { true }
  override func view() -> UIView! { RNGodotView() }
}

import UIKit
import SwiftUI
import SwiftGodot
import SwiftGodotKit

@objc(RNGodotView)
final class RNGodotView: UIView {
  private var host: UIHostingController<GodotAppView>?
  private static var app: GodotApp?
  @objc var pckName: NSString?
  @objc var onGodotEvent: RCTDirectEventBlock?

  override init(frame: CGRect) {
    super.init(frame: frame)
    BridgeCenter.shared.toRN = { [weak self] json in
      self?.onGodotEvent?(["data": json])
    }
    mountIfNeeded()
  }
  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  private func mountIfNeeded() {
    guard host == nil else { return }
    let pack = (pckName as String?) ?? "game.pck"
    if RNGodotView.app == nil { RNGodotView.app = GodotApp(packFile: pack) }
    let root = GodotAppView().environment(.godotApp, RNGodotView.app!)
    let hc = UIHostingController(rootView: root)
    host = hc
    hc.view.backgroundColor = .clear
    addSubview(hc.view)
    hc.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hc.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      hc.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      hc.view.topAnchor.constraint(equalTo: topAnchor),
      hc.view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
  }
}

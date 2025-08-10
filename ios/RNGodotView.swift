import UIKit
import SwiftUI
import SwiftGodot
import SwiftGodotKit

final class RNGodotView: UIView {
  private var host: UIHostingController<GodotAppView>?
  private static var app: GodotApp? // Godot solo permite 1 instancia

  @objc var pckName: NSString? { // Prop RN
    didSet { mountIfNeeded() }
  }

  @objc var onGodotEvent: RCTDirectEventBlock? // Evento RN ← Godot

  override init(frame: CGRect) {
    super.init(frame: frame)
    mountIfNeeded()
    BridgeCenter.shared.toRN = { [weak self] json in
      self?.onGodotEvent?(["data": json])
    }
  }
  required init?(coder: NSCoder) { fatalError() }

  private func mountIfNeeded() {
    guard host == nil else { return }
    let pack = (pckName as String?) ?? "game.pck"

    // 1) Crea (o reutiliza) GodotApp
    if RNGodotView.app == nil {
      RNGodotView.app = GodotApp(packFile: pack) // carga el .pck del bundle
    }

    // 2) Embebe el GodotAppView con el environment adecuado
    let root = GodotAppView().environment(\.godotApp, RNGodotView.app!)
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

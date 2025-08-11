import Foundation
import UIKit
import React

// Exportada a ObjC con el mismo nombre que espera JS: "RNGodotView"
@objc(RNGodotView)
class GodotView: UIView {
  @objc var pckName: NSString? = nil
  @objc var onGodotEvent: RCTDirectEventBlock?

  private var hasMountedGodot = false
  private let godotContainer = UIView()

  override init(frame: CGRect) {
    super.init(frame: frame)
    if self.tag == 0 { self.tag = Int(arc4random_uniform(1_000_000)) }
    addSubview(godotContainer)
    godotContainer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      godotContainer.topAnchor.constraint(equalTo: topAnchor),
      godotContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
      godotContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
      godotContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil {
      attachGodotIfNeeded()
      RnBridge.shared.listener = { [weak self] payload in
        guard let self = self else { return }
        self.onGodotEvent?(["data": payload])
      }
    } else {
      detachGodotIfNeeded()
      RnBridge.shared.listener = nil
    }
  }

  private func attachGodotIfNeeded() {
    guard !hasMountedGodot, let hostVC = nearestViewController() else { return }
    hasMountedGodot = true

    // 1) Instancia tu UIViewController de Godot
    // IMPORTANTE: Sustituye este método por la creación real del VC de Godot.
    // Por ejemplo, si tu framework expone GodotViewController():
    // let godotVC = GodotViewController(commandLine: ["--main-pack", "res://game.pck"])
    let godotVC = createGodotViewController()

    // 2) Embébelo como hijo
    hostVC.addChild(godotVC)
    godotVC.view.frame = godotContainer.bounds
    godotVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    godotContainer.addSubview(godotVC.view)
    godotVC.didMove(toParent: hostVC)
  }

  private func detachGodotIfNeeded() {
    guard let hostVC = nearestViewController() else { return }
    for child in hostVC.children {
      // Si usas un tipo específico (p.ej. GodotViewController), filtra aquí.
      if child.view.isDescendant(of: godotContainer) {
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
      }
    }
    hasMountedGodot = false
  }

  private func nearestViewController() -> UIViewController? {
    var nextResponder: UIResponder? = self
    while let responder = nextResponder {
      if let vc = responder as? UIViewController { return vc }
      nextResponder = responder.next
    }
    return nil
  }

  // Sustituye el contenido de este método por la inicialización real de tu VC de Godot.
  private func createGodotViewController() -> UIViewController {
    // TODO: crea y devuelve el UIViewController de Godot aquí.
    // Debe cargar tu .pck (p.ej. con ["--main-pack", "res://<nombre>.pck"])
    // Puedes usar pckName si quieres anular el nombre autodetectado.
    let placeholder = UIViewController()
    placeholder.view.backgroundColor = .black
    let label = UILabel()
    label.text = "Godot VC aquí"
    label.textColor = .white
    label.translatesAutoresizingMaskIntoConstraints = false
    placeholder.view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: placeholder.view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: placeholder.view.centerYAnchor),
    ])
    return placeholder
  }
}

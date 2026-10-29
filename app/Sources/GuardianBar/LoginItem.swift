import Foundation
import Observation
import ServiceManagement

/// Abrir la app al iniciar sesión (SMAppService.mainApp).
///
/// La primera vez que se abre **desde /Applications** se registra sola; después
/// manda la casilla del menú (si el usuario la quita, no se vuelve a poner).
/// Desde otra carpeta no se registra sola: el ítem apuntaría a una copia que
/// puede desaparecer (app/build se borra en cada compilación).
/// Solo dentro del paquete .app: con el binario suelto no hace nada.
@MainActor
enum LoginItem {
  static let configuredKey = "loginItemConfigured"

  static var available: Bool {
    Bundle.main.bundleIdentifier != nil
  }

  static var isEnabled: Bool {
    available && SMAppService.mainApp.status == .enabled
  }

  /// Si falla, se vuelve a intentar la próxima vez que se abra la app.
  static func registerOnFirstLaunch() {
    guard available, Bundle.main.bundlePath.hasPrefix("/Applications/"),
          !UserDefaults.standard.bool(forKey: configuredKey) else { return }
    if set(true) == nil {
      UserDefaults.standard.set(true, forKey: configuredKey)
    }
  }

  /// Devuelve el error, o nil si salió bien.
  static func set(_ enabled: Bool) -> String? {
    guard available else { return "Solo funciona con la app compilada (zsh app/build.zsh)." }
    do {
      if enabled {
        try SMAppService.mainApp.register()
        // macOS puede pedir que el usuario lo apruebe en Ajustes.
        if SMAppService.mainApp.status == .requiresApproval {
          SMAppService.openSystemSettingsLoginItems()
        }
      } else {
        try SMAppService.mainApp.unregister()
      }
      return nil
    } catch {
      return error.localizedDescription
    }
  }
}

/// La casilla "Abrir al iniciar sesión" del menú. Solo se asigna si cambia: cada
/// vez que SwiftUI redibuja el menú, macOS cierra el submenú abierto (ver AppModel).
@MainActor @Observable
final class LoginItemToggle {
  private(set) var isOn = LoginItem.isEnabled

  /// Se vuelve a leer en cada lectura del estado: puede cambiar desde Ajustes.
  func reread() {
    let enabled = LoginItem.isEnabled
    if enabled != isOn { isOn = enabled }
  }

  func set(_ enabled: Bool) {
    if let error = LoginItem.set(enabled) {
      Alerts.show("No se pudo cambiar el inicio de sesión", error)
    }
    reread()
  }
}

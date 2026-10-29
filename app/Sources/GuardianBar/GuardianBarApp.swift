import SwiftUI

/// Punto de entrada: un ícono en la barra de menús con un menú nativo.
/// Sin ventana y sin ícono en el Dock (LSUIElement en Info.plist).
@main
struct GuardianBarApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    MenuBarExtra {
      MenuContent(model: model)
    } label: {
      MenuBarLabel(icon: model.icon)
    }
    .menuBarExtraStyle(.menu)
  }
}

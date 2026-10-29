import GuardianCore
import SwiftUI

/// El menú que se abre al hacer clic en el ícono. Qué opciones hay, y si están
/// activas, lo deciden MenuModel y MenuSummary; aquí solo se dibujan.
struct MenuContent: View {
  let model: AppModel

  var body: some View {
    // El resumen: líneas sin acción (macOS las muestra en gris).
    ForEach(Array(model.summary.enumerated()), id: \.offset) { line in
      Text(line.element)
    }
    Divider()

    if let menu = model.menu, let status = model.result.status {
      actions(menu)
      Divider()
      SettingsMenu(status: status)
    } else if model.result != .loading {
      Button("Reintentar") {
        Task { await model.refresh() }
      }
    }

    Toggle("Abrir al iniciar sesión", isOn: Binding(
      get: { model.opensAtLogin },
      set: { model.setOpensAtLogin($0) }
    ))
    Divider()
    Button("Salir") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }

  @ViewBuilder
  private func actions(_ menu: MenuModel) -> some View {
    if let pass = menu.pass {
      button(pass)
    }
    if let title = menu.newSessionTitle {
      Menu(title) {
        ForEach(menu.newSession) { button($0) }
      }
    }
    if let stop = menu.stop {
      button(stop)
    }
    if let cancelStop = menu.cancelStop {
      button(cancelStop)
    }
  }

  private func button(_ action: MenuAction) -> some View {
    Button(action.title) {
      Task { await model.run(action.command) }
    }
    .disabled(!action.enabled)
  }
}

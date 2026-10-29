import GuardianCore
import SwiftUI

/// El menú que se abre al hacer clic en el ícono. Qué opciones hay, y si están
/// activas, lo decide MenuSnapshot; aquí solo se dibujan. Solo lee valores que
/// cambian cuando cambia lo que se ve (ver AppModel).
struct MenuContent: View {
  let model: AppModel

  var body: some View {
    // El resumen: líneas sin acción (macOS las muestra en gris).
    ForEach(Array(model.screen.summary.enumerated()), id: \.offset) { line in
      Text(line.element)
    }
    Divider()

    if let menu = model.screen.menu {
      actions(menu)
      Divider()
      SettingsMenu(lines: model.screen.settings)
    } else if model.screen.offersRetry {
      Button("Reintentar") {
        Task { await model.refresh() }
      }
    }

    Toggle("Abrir al iniciar sesión", isOn: Binding(
      get: { model.loginItem.isOn },
      set: { model.loginItem.set($0) }
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

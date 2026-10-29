import GuardianCore
import SwiftUI

/// El submenú "Configuración": solo lectura en la v1. Cambiarla exige sudo a
/// propósito (fricción), así que aquí solo se explica cómo.
struct SettingsMenu: View {
  let status: GuardianStatus

  var body: some View {
    Menu("Configuración") {
      ForEach(MenuSummary.settings(status), id: \.self) { line in
        Text(line)
      }
      Divider()
      ForEach(MenuSummary.howToChange, id: \.self) { line in
        Text(line)
      }
    }
  }
}

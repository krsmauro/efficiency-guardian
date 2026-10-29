import GuardianCore
import SwiftUI

/// El submenú "Configuración": solo lectura en la v1. Cambiarla exige sudo a
/// propósito (fricción), así que aquí solo se explica cómo.
struct SettingsMenu: View {
  /// Las líneas de MenuSummary.settings, ya calculadas en MenuSnapshot.
  let lines: [String]

  var body: some View {
    Menu("Configuración") {
      ForEach(lines, id: \.self) { line in
        Text(line)
      }
      Divider()
      ForEach(MenuSummary.howToChange, id: \.self) { line in
        Text(line)
      }
    }
  }
}

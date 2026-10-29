import GuardianCore
import SwiftUI

/// El ícono de la barra de menús y, a veces, una cuenta atrás ("47m", "3:12").
/// Qué se muestra lo decide IconState.
///
/// Lee el ícono aquí y no en GuardianBarApp: así, cuando cambia cada segundo,
/// SwiftUI redibuja solo la etiqueta y no toda la escena (con el menú).
struct MenuBarLabel: View {
  let model: AppModel

  var body: some View {
    let icon = model.icon
    HStack(spacing: 3) {
      Image(systemName: icon.symbol)
      if let text = icon.text {
        // Cifras de ancho fijo: el ícono no baila al cambiar los segundos.
        Text(text).monospacedDigit()
      }
    }
    .accessibilityLabel("Efficiency Guardian")
  }
}

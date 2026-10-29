import GuardianCore
import SwiftUI

/// El ícono de la barra de menús y, a veces, una cuenta atrás ("47m", "3:12").
/// Qué se muestra lo decide IconState.
struct MenuBarLabel: View {
  let icon: IconState

  var body: some View {
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

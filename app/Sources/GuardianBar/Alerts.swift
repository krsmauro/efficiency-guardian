import AppKit

/// Una alerta para explicar un error (por ejemplo, un comando que el motor
/// rechazó). Una alerta no necesita permiso, a diferencia de una notificación.
@MainActor
enum Alerts {
  /// Programa la alerta y vuelve en el acto, sin esperar a que se cierre.
  ///
  /// Se abre desde el run loop y no desde la tarea que llama: una alerta modal
  /// abierta dentro de una tarea del hilo principal congela las demás tareas
  /// (leer el estado, los avisos de la carpeta del motor) hasta que se cierra.
  /// La cuenta atrás seguiría bajando sobre un estado viejo. Lo encontró la
  /// revisión del 2026-10-29.
  static func show(_ title: String, _ message: String) {
    RunLoop.main.perform {
      MainActor.assumeIsolated { present(title, message) }
    }
  }

  private static func present(_ title: String, _ message: String) {
    // Sin esto, en una app sin Dock la alerta podría quedar detrás de otras ventanas.
    NSApp.activate()
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = title
    alert.informativeText = message
    alert.runModal()
  }
}

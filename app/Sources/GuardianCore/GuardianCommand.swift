/// Los comandos que la app puede pedir al motor.
///
/// Sus argumentos deben ser **exactamente** los de la regla de sudoers
/// (install/sudoers.zsh): start, start <cada duración de TIMED_PRESETS>, stop,
/// cancel-stop y pass. Con cualquier otro, `sudo -n` falla en vez de pedir
/// contraseña. `status` no lleva sudo.
public enum GuardianCommand: Equatable, Sendable {
  /// Sesión sin fin; con una sesión en curso, cancela una terminación pendiente.
  case start
  /// Sesión por tiempo (una duración de TIMED_PRESETS); convierte una sin fin.
  case startTimed(Int)
  /// Terminar, con el retraso de STOP_DELAY_MINUTES.
  case stop
  /// "Seguir trabajando": anula la terminación pendiente.
  case cancelStop
  /// Pase temporal para PASS_GROUPS.
  case pass

  public static let enginePath = "/usr/local/sbin/guardian"
  public static let sudoPath = "/usr/bin/sudo"
  public static let statusArguments = ["status", "--json"]

  public var arguments: [String] {
    switch self {
    case .start: ["start"]
    case .startTimed(let minutes): ["start", String(minutes)]
    case .stop: ["stop"]
    case .cancelStop: ["cancel-stop"]
    case .pass: ["pass"]
    }
  }

  /// Los argumentos de sudo. `-n`: nunca pedir contraseña (falla si la regla no lo permite).
  public var sudoArguments: [String] {
    ["-n", Self.enginePath] + arguments
  }
}

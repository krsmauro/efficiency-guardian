/// Los comandos que la app puede pedir al motor.
///
/// Sus argumentos deben caber en la regla de sudoers (install/sudoers.zsh):
/// start, stop, cancel-stop, pass y extend sin nada; start, extend y shorten con
/// un número de 1 a 3 cifras; pass con un nombre de grupo. Con cualquier otro,
/// `sudo -n` falla en vez de pedir contraseña. El motor, además, solo acepta
/// las duraciones de TIMED_PRESETS y los grupos de PASS_GROUPS. `status` no
/// lleva sudo.
public enum GuardianCommand: Equatable, Sendable {
  /// Sesión sin fin; con una sesión en curso, cancela una terminación pendiente.
  case start
  /// Sesión por tiempo (una duración de TIMED_PRESETS); convierte una sin fin.
  case startTimed(Int)
  /// Terminar, con el retraso de STOP_DELAY_MINUTES.
  case stop
  /// "Seguir trabajando": anula la terminación pendiente.
  case cancelStop
  /// Pase temporal para un grupo de PASS_GROUPS.
  case pass(String)
  /// La sesión por tiempo pasa a durar N minutos en total (más que ahora).
  case extend(Int)
  /// La sesión por tiempo pasa a ser sin fin ("Alargar ▸ Sin fin").
  case extendEndless
  /// Acortar la sesión por tiempo a N minutos; nunca antes que el retraso al terminar.
  case shorten(Int)

  public static let enginePath = "/usr/local/sbin/guardian"
  public static let sudoPath = "/usr/bin/sudo"
  public static let statusArguments = ["status", "--json"]

  public var arguments: [String] {
    switch self {
    case .start: ["start"]
    case .startTimed(let minutes): ["start", String(minutes)]
    case .stop: ["stop"]
    case .cancelStop: ["cancel-stop"]
    case .pass(let group): ["pass", group]
    case .extend(let minutes): ["extend", String(minutes)]
    case .extendEndless: ["extend"]
    case .shorten(let minutes): ["shorten", String(minutes)]
    }
  }

  /// Los argumentos de sudo. `-n`: nunca pedir contraseña (falla si la regla no lo permite).
  public var sudoArguments: [String] {
    ["-n", Self.enginePath] + arguments
  }
}

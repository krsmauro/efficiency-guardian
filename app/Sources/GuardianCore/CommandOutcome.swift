/// El resultado de un comando, listo para mostrar.
public enum CommandOutcome: Equatable, Sendable {
  /// El mensaje del motor, por ejemplo "Sesión sin fin iniciada. 82 dominios bloqueados."
  case success(String)
  /// Por qué no se hizo, explicado.
  case failure(String)

  /// Lo que dice sudo (en inglés: la app lo ejecuta sin LANG) cuando la regla
  /// de sudoers no permite el comando y haría falta la contraseña.
  static let sudoNeedsPassword = "a password is required"

  public static let needsPasswordMessage = """
    sudo pidió la contraseña: la regla de sudoers no permite este comando. \
    Puede que el motor no esté instalado, o que hayas cambiado TIMED_PRESETS \
    sin volver a ejecutar el instalador (sudo ./install.sh).
    """

  public static func interpret(exitCode: Int32, stdout: String, stderr: String) -> CommandOutcome {
    if exitCode == 0 {
      return .success(EngineMessage.clean(stdout) ?? "")
    }
    if stderr.contains(sudoNeedsPassword) {
      return .failure(needsPasswordMessage)
    }
    return .failure(EngineMessage.clean(stderr) ?? "El motor salió con el código \(exitCode).")
  }
}

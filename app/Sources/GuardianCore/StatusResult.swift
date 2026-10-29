import Foundation

/// Lo que la app sabe del motor en cada momento.
public enum StatusResult: Equatable, Sendable {
  /// Todavía no se leyó (solo al abrir la app, unos milisegundos).
  case loading
  /// No existe /usr/local/sbin/guardian.
  case notInstalled
  /// El motor falló o respondió algo inesperado; el texto explica qué.
  case failed(String)
  case ok(GuardianStatus)

  /// Interpreta la salida de `guardian status --json`. Los avisos que el motor
  /// escribe en stderr con código 0 (por ejemplo, un estado dañado que ya
  /// corrigió) no impiden leer el estado.
  public static func interpret(exitCode: Int32, stdout: Data, stderr: String) -> StatusResult {
    guard exitCode == 0 else {
      return .failed(EngineMessage.clean(stderr) ?? "El motor salió con el código \(exitCode).")
    }
    do {
      return .ok(try GuardianStatus.decode(stdout))
    } catch {
      return .failed("Respuesta inesperada del motor. ¿La app y el motor son de versiones distintas?")
    }
  }

  /// El estado, si se pudo leer.
  public var status: GuardianStatus? {
    if case .ok(let status) = self { return status }
    return nil
  }
}

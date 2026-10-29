import Foundation

/// La salida de un programa.
public struct ProcessOutput: Sendable {
  public let exitCode: Int32
  public let stdout: Data
  public let stderr: Data

  public var stdoutText: String { String(decoding: stdout, as: UTF8.self) }
  public var stderrText: String { String(decoding: stderr, as: UTF8.self) }
}

/// Ejecuta un programa y devuelve su salida. Es la única parte de GuardianCore
/// que toca el sistema; sus pruebas ejecutan programas de verdad.
///
/// - Sin shell: los argumentos van tal cual, nada se interpreta.
/// - Entorno limpio (solo PATH): ninguna variable de la sesión llega al motor.
///   Sin LANG, sudo responde en inglés, y CommandOutcome reconoce su mensaje.
///   (Las pruebas pasan otro entorno para apuntar el motor a archivos de prueba.)
/// - Entrada vacía: nada puede quedarse esperando una respuesta.
public enum ProcessRunner {
  public static let cleanEnvironment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]

  /// Esperar al programa bloquea un hilo, así que cada ejecución usa hilos
  /// propios (Thread), que no salen de ningún grupo con límite:
  /// - Nunca los de Swift concurrency (async/await): son tantos como núcleos.
  ///   Con más programas a la vez, todos esperaban una salida que nadie leía y
  ///   la app se colgaba (lo encontraron las pruebas el 2026-10-29).
  /// - Tampoco los de GCD: tienen un tope de 64, y con 64 programas a la vez
  ///   pasaba lo mismo (lo encontró la revisión).
  public static func run(
    _ path: String, _ arguments: [String], environment: [String: String] = cleanEnvironment
  ) async -> ProcessOutput {
    await withCheckedContinuation { continuation in
      Thread.detachNewThread {
        continuation.resume(returning: runBlocking(path, arguments, environment))
      }
    }
  }

  static func runBlocking(_ path: String, _ arguments: [String], _ environment: [String: String]) -> ProcessOutput {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.environment = environment
    process.standardInput = FileHandle.nullDevice
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe
    do {
      try process.run()
    } catch {
      let message = "No se pudo ejecutar \(path): \(error.localizedDescription)"
      return ProcessOutput(exitCode: -1, stdout: Data(), stderr: Data(message.utf8))
    }
    // Las dos salidas se leen a la vez (stderr en otro hilo): si una se llenara
    // mientras se espera la otra, el programa se quedaría bloqueado escribiendo.
    let stderrHandle = stderrPipe.fileHandleForReading
    let stderr = DataBox()
    let stderrDone = DispatchSemaphore(value: 0)
    Thread.detachNewThread {
      stderr.value = stderrHandle.readDataToEndOfFile()
      stderrDone.signal()
    }
    let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    stderrDone.wait()
    process.waitUntilExit()
    return ProcessOutput(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr.value)
  }
}

/// Lo escribe un hilo y lo lee otro, pero solo después de stderrDone.wait(),
/// que ordena los dos accesos. Por eso no necesita candado.
private final class DataBox: @unchecked Sendable {
  var value = Data()
}

import Foundation
import GuardianCore

/// Habla con el motor instalado: lee el estado (sin sudo) y ejecuta comandos
/// (con `sudo -n`, que solo funciona con los argumentos exactos de la regla de
/// sudoers). Las rutas son fijas: la app nunca ejecuta otra cosa.
enum GuardianClient {
  static func status() async -> StatusResult {
    guard FileManager.default.isExecutableFile(atPath: GuardianCommand.enginePath) else {
      return .notInstalled
    }
    let output = await ProcessRunner.run(GuardianCommand.enginePath, GuardianCommand.statusArguments)
    return StatusResult.interpret(exitCode: output.exitCode, stdout: output.stdout, stderr: output.stderrText)
  }

  static func run(_ command: GuardianCommand) async -> CommandOutcome {
    let output = await ProcessRunner.run(GuardianCommand.sudoPath, command.sudoArguments)
    return CommandOutcome.interpret(exitCode: output.exitCode, stdout: output.stdoutText, stderr: output.stderrText)
  }
}

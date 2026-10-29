import Testing
@testable import GuardianCore

@Suite("Comandos")
struct CommandTests {
  // Deben ser los de la regla de sudoers (install/sudoers.zsh), palabra por palabra.
  @Test("Argumentos exactos")
  func arguments() {
    #expect(GuardianCommand.start.arguments == ["start"])
    #expect(GuardianCommand.startTimed(25).arguments == ["start", "25"])
    #expect(GuardianCommand.stop.arguments == ["stop"])
    #expect(GuardianCommand.cancelStop.arguments == ["cancel-stop"])
    #expect(GuardianCommand.pass.arguments == ["pass"])
  }

  @Test("sudo -n con la ruta fija del motor")
  func sudo() {
    #expect(GuardianCommand.sudoPath == "/usr/bin/sudo")
    #expect(GuardianCommand.startTimed(50).sudoArguments == ["-n", "/usr/local/sbin/guardian", "start", "50"])
    #expect(GuardianCommand.statusArguments == ["status", "--json"])
  }

  @Test("Éxito: el mensaje del motor")
  func success() {
    let outcome = CommandOutcome.interpret(
      exitCode: 0, stdout: "Sesión sin fin iniciada. 82 dominios bloqueados.\n", stderr: "")
    #expect(outcome == .success("Sesión sin fin iniciada. 82 dominios bloqueados."))
  }

  @Test("Rechazo del motor: su mensaje, sin prefijo")
  func engineError() {
    let outcome = CommandOutcome.interpret(
      exitCode: 1, stdout: "", stderr: "guardian: error: sesión con candado: termina a las 10:30\n")
    #expect(outcome == .failure("Sesión con candado: termina a las 10:30"))
  }

  @Test("sudo pide contraseña: se explica por qué")
  func needsPassword() {
    let outcome = CommandOutcome.interpret(
      exitCode: 1, stdout: "", stderr: "sudo: a password is required\n")
    #expect(outcome == .failure(CommandOutcome.needsPasswordMessage))
    #expect(CommandOutcome.needsPasswordMessage.contains("TIMED_PRESETS"))
  }

  @Test("Sin mensaje: el código de salida")
  func silentFailure() {
    #expect(CommandOutcome.interpret(exitCode: 2, stdout: "", stderr: "")
            == .failure("El motor salió con el código 2."))
  }
}

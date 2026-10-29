import Foundation
import Testing
@testable import GuardianCore

/// El motor del repositorio (bin/guardian), sin root, sobre una copia del hosts
/// de prueba, como hacen las pruebas de zsh (tests/e2e.zsh). Comprueba que lo
/// que la app manda (GuardianCommand) y lo que entiende (StatusResult,
/// CommandOutcome) encajan con el motor de verdad. Solo cambia la ruta: la app
/// instalada usa /usr/local/sbin/guardian con sudo -n.
final class EngineSandbox {
  static let repo = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
  let folder: URL
  var now = T0

  init() throws {
    folder = FileManager.default.temporaryDirectory.appending(path: "guardian-swift-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: Self.repo.appending(path: "tests/fixtures/hosts"), to: folder.appending(path: "hosts"))
    try FileManager.default.copyItem(at: Self.repo.appending(path: "config.default"), to: folder.appending(path: "config"))
    // Listas pequeñas y fijas: así el número de dominios no cambia al editar blocklists/.
    let lists = folder.appending(path: "lists")
    try FileManager.default.createDirectory(at: lists, withIntermediateDirectories: true)
    try "youtube.com\nwww.youtube.com\n".write(to: lists.appending(path: "youtube.txt"), atomically: true, encoding: .utf8)
    try "facebook.com\n".write(to: lists.appending(path: "facebook.txt"), atomically: true, encoding: .utf8)
  }

  deinit {
    try? FileManager.default.removeItem(at: folder)
  }

  private func engine(_ arguments: [String]) async -> ProcessOutput {
    let environment = ProcessRunner.cleanEnvironment.merging([
      "GUARDIAN_LIB_DIR": Self.repo.appending(path: "lib").path,
      "GUARDIAN_BLOCKLIST_DIR": folder.appending(path: "lists").path,
      "GUARDIAN_HOSTS_FILE": folder.appending(path: "hosts").path,
      "GUARDIAN_DATA_DIR": folder.appending(path: "data").path,
      "GUARDIAN_CONFIG": folder.appending(path: "config").path,
      "GUARDIAN_NOW": String(now), "GUARDIAN_BOOT_ID": "boot1", "TZ": "UTC",
    ]) { _, new in new }
    return await ProcessRunner.run(Self.repo.appending(path: "bin/guardian").path, arguments, environment: environment)
  }

  func status() async -> StatusResult {
    let out = await engine(GuardianCommand.statusArguments)
    return StatusResult.interpret(exitCode: out.exitCode, stdout: out.stdout, stderr: out.stderrText)
  }

  func run(_ command: GuardianCommand) async -> CommandOutcome {
    await run(command.arguments)
  }

  func run(_ arguments: [String]) async -> CommandOutcome {
    let out = await engine(arguments)
    return CommandOutcome.interpret(exitCode: out.exitCode, stdout: out.stdoutText, stderr: out.stderrText)
  }
}

@Suite("La app con el motor del repositorio", .timeLimit(.minutes(1)))
struct EngineIntegrationTests {
  @Test("Una sesión de punta a punta: lo que ve y lo que manda la app")
  func session() async throws {
    let engine = try EngineSandbox()
    #expect(await engine.status().status?.session == GuardianStatus.Session.none)

    #expect(await engine.run(.startTimed(25)) == .success("Sesión de 25 min iniciada: termina a las 08:25. 3 dominios bloqueados."))
    let timed = try #require(await engine.status().status)
    #expect(timed.session == .timed && timed.blocking)
    #expect(IconState.from(.ok(timed), now: T0) == IconState(symbol: "lock.fill", text: "25m"))
    #expect(MenuModel(status: timed, now: T0, timeZone: utc).pass?.command == .pass)

    engine.now = at(1)
    #expect(await engine.run(.pass) == .success("Pase: youtube desbloqueado hasta las 08:06. Te quedan 2 de 3."))
    #expect(await engine.run(.pass) == .failure("Ya hay un pase en curso, hasta las 08:06"))
    #expect(await engine.run(.stop) == .success(
      "El bloqueo sigue hasta las 08:06, por si cambias de opinión. Para seguir trabajando: guardian cancel-stop."))
    let pending = try #require(await engine.status().status)
    #expect(IconState.from(.ok(pending), now: at(1)).symbol == "ticket")
    #expect(MenuModel(status: pending, now: at(1), timeZone: utc).cancelStop?.command == .cancelStop)
    #expect(await engine.run(.cancelStop) == .success("Terminación cancelada: la sesión sigue."))
  }

  @Test("Rechazos del motor, explicados")
  func rejections() async throws {
    let engine = try EngineSandbox()
    #expect(await engine.run(.pass) == .failure("No hay sesión: no hace falta un pase"))
    #expect(await engine.run(.startTimed(37))
            == .failure("37 min no es una duración permitida (TIMED_PRESETS: 25, 50, 90)"))
    guard case .failure(let usage) = await engine.run(["start", "025"]) else {
      Issue.record("start 025 debería fallar")
      return
    }
    #expect(usage.hasPrefix("Uso: guardian start [minutos]"))
  }
}

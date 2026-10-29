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

  /// Añade una línea a la configuración, por ejemplo "PASS_GROUPS=youtube,facebook".
  func configure(_ line: String) throws {
    let file = folder.appending(path: "config")
    let text = try String(contentsOf: file, encoding: .utf8)
    let key = line.prefix { $0 != "=" } + "="
    let kept = text.split(separator: "\n").filter { !$0.hasPrefix(key) }.joined(separator: "\n")
    try (kept + "\n" + line + "\n").write(to: file, atomically: true, encoding: .utf8)
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

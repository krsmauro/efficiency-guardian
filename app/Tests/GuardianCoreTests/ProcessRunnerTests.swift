import Foundation
import Testing
@testable import GuardianCore

@Suite("Ejecutar programas", .timeLimit(.minutes(1)))
struct ProcessRunnerTests {
  @Test("Salida estándar, salida de errores y código, por separado")
  func output() async {
    let out = await ProcessRunner.run("/bin/sh", ["-c", "echo hola; echo error >&2; exit 3"])
    #expect(out.exitCode == 3)
    #expect(out.stdoutText == "hola\n")
    #expect(out.stderrText == "error\n")
  }

  @Test("Los argumentos van tal cual, sin shell")
  func noShell() async {
    let out = await ProcessRunner.run("/bin/echo", ["$HOME", "`id`", "a;b"])
    #expect(out.stdoutText == "$HOME `id` a;b\n")
  }

  @Test("Entorno limpio: solo PATH")
  func cleanEnvironment() async {
    let out = await ProcessRunner.run("/usr/bin/env", [])
    #expect(out.stdoutText == "PATH=/usr/bin:/bin:/usr/sbin:/sbin\n")
  }

  @Test("Entrada vacía: nada se queda esperando")
  func emptyInput() async {
    let out = await ProcessRunner.run("/bin/cat", [])
    #expect(out.exitCode == 0 && out.stdout.isEmpty)
  }

  @Test("Mucha salida por los dos lados no lo bloquea")
  func largeOutput() async {
    let script = "head -c 300000 /dev/zero | tr '\\0' a >&2; head -c 300000 /dev/zero | tr '\\0' b"
    let out = await ProcessRunner.run("/bin/sh", ["-c", script])
    #expect(out.exitCode == 0)
    #expect(out.stdout.count == 300_000 && out.stderr.count == 300_000)
  }

  // La espera ocupó primero los hilos de Swift concurrency (tantos como
  // núcleos) y después los de GCD (tope de 64): con más programas a la vez,
  // todo se colgaba. Si esta prueba no termina, ha vuelto ese fallo (ver
  // ProcessRunner.run).
  @Test("Más programas a la vez que núcleos y que el tope de GCD, con mucha salida, no lo cuelgan")
  func manyAtOnce() async {
    let count = max(70, ProcessInfo.processInfo.activeProcessorCount + 4)
    let script = "head -c 100000 /dev/zero >&2; head -c 100000 /dev/zero"
    let sizes = await withTaskGroup(of: Int.self) { group in
      for _ in 0..<count {
        group.addTask { await ProcessRunner.run("/bin/sh", ["-c", script]).stderr.count }
      }
      return await group.reduce(into: []) { $0.append($1) }
    }
    #expect(sizes == Array(repeating: 100_000, count: count))
  }

  @Test("Un programa que no existe")
  func missingProgram() async {
    let out = await ProcessRunner.run("/no/existe", [])
    #expect(out.exitCode == -1)
    #expect(out.stderrText.hasPrefix("No se pudo ejecutar /no/existe"))
  }
}

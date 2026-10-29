import Testing
@testable import GuardianCore

@Suite("Ícono de la barra de menús")
struct IconStateTests {
  @Test("Sin leer, sin motor o con error")
  func problems() {
    #expect(IconState.from(.loading, now: T0) == .loading)
    #expect(IconState.from(.notInstalled, now: T0) == .problem)
    #expect(IconState.from(.failed("x"), now: T0) == .problem)
  }

  @Test("Sin sesión: candado abierto, sin texto")
  func idle() throws {
    #expect(IconState.from(.ok(try status()), now: T0) == IconState(symbol: "lock.open"))
  }

  @Test("Sesión sin fin: candado cerrado, sin texto")
  func indefiniteSession() throws {
    #expect(IconState.from(.ok(try indefinite()), now: at(10)) == IconState(symbol: "lock.fill"))
  }

  @Test("Sesión por tiempo: los minutos que quedan")
  func timedSession() throws {
    let s = try timed()
    #expect(IconState.from(.ok(s), now: at(0)) == IconState(symbol: "lock.fill", text: "25m"))
    #expect(IconState.from(.ok(s), now: at(24, seconds: 30)) == IconState(symbol: "lock.fill", text: "1m"))
  }

  @Test("Terminación pendiente: cuenta atrás hasta el fin de verdad")
  func stopPending() throws {
    let s = try indefinite { $0.stopAt = at(15) }
    #expect(IconState.from(.ok(s), now: at(10, seconds: 50)) == IconState(symbol: "hourglass", text: "4:10"))
    let endsFirst = try timed { $0.stopAt = at(28) }
    #expect(IconState.from(.ok(endsFirst), now: at(23)) == IconState(symbol: "hourglass", text: "2:00"))
  }

  @Test("El pase manda sobre todo lo demás")
  func passWins() throws {
    let s = try timed {
      $0.passUntil = at(6)
      $0.stopAt = at(8)
    }
    #expect(IconState.from(.ok(s), now: at(2, seconds: 48)) == IconState(symbol: "ticket", text: "3:12"))
    #expect(IconState.from(.ok(s), now: at(6)).symbol == "hourglass")
  }
}

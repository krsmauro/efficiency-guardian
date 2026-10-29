import Foundation
import Testing
@testable import GuardianCore

@Suite("Leer status --json")
struct StatusDecodingTests {
  @Test("Sin sesión")
  func none() throws {
    let s = try fixture("none")
    #expect(s.session == .none)
    #expect(s.now == T0)
    #expect(s.timedPresets == [25, 50, 90])
    #expect(s.passGroups == ["youtube"] && s.passGroup == "")
    #expect(s.timedStarted == 0)
    #expect(!s.blocking && s.blockedDomains == 0)
    #expect(!s.stopPending)
  }

  @Test("Sesión sin fin")
  func indefinite() throws {
    let s = try fixture("indefinite")
    #expect(s.session == .indefinite)
    #expect(s.sessionStarted == T0 && s.sessionEnds == 0)
    #expect(s.blocking && s.blockedDomains == 3)
    #expect(s.nextDeadline(after: s.now) == nil)
  }

  @Test("Sesión por tiempo con pase y terminación pendiente")
  func timedPassStop() throws {
    let s = try fixture("timed-pass-stop")
    #expect(s.session == .timed)
    #expect(s.now == at(4))
    #expect(s.sessionEnds == at(25) && s.timedStarted == T0)
    #expect(s.passUntil == at(6) && s.passActive(at: s.now) && s.passGroup == "youtube")
    #expect(s.stopAt == at(8) && s.stopPending && s.effectiveStopAt == at(8))
    #expect(s.passesUsed == 1 && s.passesLeft == 2)
    #expect(s.nextDeadline(after: s.now) == at(6))
    #expect(s.nextDeadline(after: at(6)) == at(8))
    #expect(s.nextDeadline(after: at(8)) == at(25))
  }

  @Test("Candado, sin fin convertida, pase del segundo grupo y otra configuración")
  func locked() throws {
    let s = try fixture("locked")
    #expect(s.timedLock && !s.autostartAtBoot)
    #expect(s.passGroups == ["youtube", "facebook"] && s.passGroup == "facebook")
    #expect(s.timedPresets == [15, 45])
    // Convertida en el minuto 10: la parte por tiempo empieza ahí, no en T0.
    #expect(s.sessionStarted == T0 && s.timedStarted == at(10) && s.sessionEnds == at(55))
  }

  @Test("¿Llegó la próxima hora de fin? Contando desde la hora del motor")
  func deadlinePassed() throws {
    let s = try fixture("timed-pass-stop")   // leído a las 08:04; el pase vence a las 08:06
    #expect(!s.deadlinePassed(at: at(5)))
    #expect(s.deadlinePassed(at: at(6)))
    // La lectura empezó un segundo antes de la hora de fin y llegó justo a esa hora.
    // (Aquí "indefinite" es la prueba de arriba, así que se usa el archivo del motor.)
    var straddling = try fixture("indefinite")
    straddling.now = at(6) - 1
    straddling.passUntil = at(6)
    #expect(straddling.deadlinePassed(at: at(6)))
    #expect(!(try fixture("indefinite")).deadlinePassed(at: at(600)))
  }

  @Test("La terminación pendiente acaba antes si la sesión por tiempo acaba antes")
  func effectiveStop() throws {
    let s = try timed { $0.stopAt = at(28) }
    #expect(s.effectiveStopAt == at(25))
  }

  @Test("Rechaza una sesión desconocida o una clave que falta")
  func rejectsBadJSON() throws {
    let text = String(decoding: try fixtureData("none"), as: UTF8.self)
    let unknown = text.replacingOccurrences(of: "\"none\"", with: "\"paused\"")
    #expect(throws: (any Error).self) { try GuardianStatus.decode(Data(unknown.utf8)) }
    let missing = text.replacingOccurrences(of: "\"stop_at\": 0,", with: "")
    #expect(throws: (any Error).self) { try GuardianStatus.decode(Data(missing.utf8)) }
  }

  @Test("Interpretar la salida de status")
  func interpret() throws {
    let good = try fixtureData("none")
    #expect(StatusResult.interpret(exitCode: 0, stdout: good, stderr: "").status?.session == GuardianStatus.Session.none)
    #expect(StatusResult.interpret(exitCode: 0, stdout: good, stderr: "guardian: aviso: estado dañado").status != nil)
    #expect(StatusResult.interpret(exitCode: 1, stdout: Data(), stderr: "guardian: error: marcadores dañados en /etc/hosts\n")
            == .failed("Marcadores dañados en /etc/hosts"))
    #expect(StatusResult.interpret(exitCode: 1, stdout: Data(), stderr: "") == .failed("El motor salió con el código 1."))
    guard case .failed = StatusResult.interpret(exitCode: 0, stdout: Data("Sesión: ninguna".utf8), stderr: "") else {
      Issue.record("un texto que no es JSON debería ser un error")
      return
    }
  }
}

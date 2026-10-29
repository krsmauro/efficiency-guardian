import Testing
@testable import GuardianCore

// Fallo de la verificación 5.6 (2026-10-29): el menú se redibujaba cada segundo
// y macOS cerraba el submenú abierto a los 1-2 s. La app solo lo redibuja cuando
// cambia MenuSnapshot, así que no debe cambiar si lo que se ve es igual.
@Suite("Lo que dibuja el menú")
struct MenuSnapshotTests {
  func snapshot(_ s: GuardianStatus, now: Int, busy: Bool = false) -> MenuSnapshot {
    MenuSnapshot(result: .ok(s), now: now, busy: busy, timeZone: utc)
  }

  @Test("Sesión sin fin: no cambia de un segundo a otro ni con una lectura nueva")
  func stableIndefinite() throws {
    let s = try indefinite()
    let first = snapshot(s, now: at(10))
    for second in 1...59 {
      #expect(snapshot(s, now: at(10, seconds: second)) == first)
    }
    // Cada lectura trae otra hora del motor (now): tampoco cuenta.
    var reread = s
    reread.now = at(10, seconds: 30)
    #expect(snapshot(reread, now: at(10, seconds: 30)) == first)
  }

  @Test("Con pase y terminación pendiente, el ícono cuenta los segundos pero el menú no cambia")
  func stableDuringCountdowns() throws {
    let s = try fixture("timed-pass-stop")  // en at(4): pase hasta at(6), fin a at(8)
    let first = snapshot(s, now: at(4))
    for second in 1...59 {
      #expect(snapshot(s, now: at(4, seconds: second)) == first)
    }
    #expect(IconState.from(.ok(s), now: at(4, seconds: 1)) != IconState.from(.ok(s), now: at(4, seconds: 2)))
  }

  @Test("Sí cambia cuando cambia lo que se ve")
  func changesWhenVisible() throws {
    let s = try indefinite()
    #expect(snapshot(s, now: at(10), busy: true) != snapshot(s, now: at(10)))
    #expect(snapshot(try indefinite { $0.passesUsed = 1 }, now: at(10)) != snapshot(s, now: at(10)))
    // La sesión por tiempo muestra los minutos que quedan: cambia una vez por minuto.
    let t = try timed()
    #expect(snapshot(t, now: at(4)) == snapshot(t, now: at(4, seconds: 59)))
    #expect(snapshot(t, now: at(4)) != snapshot(t, now: at(5)))
  }

  @Test("Configuración y Reintentar")
  func settingsAndRetry() throws {
    let s = try indefinite()
    #expect(snapshot(s, now: at(10)).settings == MenuSummary.settings(s))
    #expect(!snapshot(s, now: at(10)).offersRetry)
    #expect(!MenuSnapshot(result: .loading, now: T0, busy: false).offersRetry)
    let failed = MenuSnapshot(result: .failed("x"), now: T0, busy: false)
    #expect(failed.offersRetry && failed.menu == nil && failed.settings.isEmpty)
    #expect(MenuSnapshot(result: .notInstalled, now: T0, busy: false).offersRetry)
  }
}

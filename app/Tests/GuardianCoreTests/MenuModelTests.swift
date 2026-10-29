import Testing
@testable import GuardianCore

@Suite("Opciones del menú")
struct MenuModelTests {
  func menu(_ s: GuardianStatus, now: Int = T0, busy: Bool = false) -> MenuModel {
    MenuModel(status: s, now: now, busy: busy, timeZone: utc)
  }

  @Test("Sin sesión: nueva sesión con las duraciones y sin fin; el pase no se puede usar")
  func idle() throws {
    let m = menu(try status())
    #expect(m.newSessionTitle == "Nueva sesión")
    #expect(m.newSession.map(\.title) == ["25 min", "50 min", "90 min", "Sin fin"])
    #expect(m.newSession.map(\.command) == [.startTimed(25), .startTimed(50), .startTimed(90), .start])
    #expect(m.pass == MenuAction("Pase YouTube: solo durante una sesión", .pass, enabled: false))
    #expect(m.stop == nil && m.cancelStop == nil)
  }

  @Test("Las duraciones salen de la configuración del motor")
  func presetsFromEngine() throws {
    let m = menu(try fixture("locked"), now: T0)
    #expect(m.newSession.isEmpty && m.newSessionTitle == nil)
    #expect(menu(try status { $0.timedPresets = [15, 45] }).newSession.map(\.title) == ["15 min", "45 min", "Sin fin"])
  }

  @Test("Sesión sin fin: pase, pasar a sesión por tiempo (sin 'Sin fin') y terminar con retraso")
  func indefiniteSession() throws {
    let m = menu(try indefinite(), now: at(10))
    #expect(m.pass == MenuAction("Pase YouTube, 5 min (quedan 3)", .pass))
    #expect(m.newSessionTitle == "Pasar a sesión por tiempo")
    #expect(m.newSession.map(\.command) == [.startTimed(25), .startTimed(50), .startTimed(90)])
    #expect(m.stop == MenuAction("Terminar sesión (en 5 min)", .stop))
    #expect(m.cancelStop == nil)
  }

  @Test("Sesión por tiempo: sin submenú de sesión")
  func timedSession() throws {
    let m = menu(try timed())
    #expect(m.newSessionTitle == nil && m.newSession.isEmpty)
    #expect(m.stop == MenuAction("Terminar sesión (en 5 min)", .stop))
    #expect(menu(try timed(), now: at(21)).stop == MenuAction("Terminar sesión (ya termina a las 08:25)", .stop))
  }

  @Test("Pasar a sesión por tiempo con una duración menor que el retraso: el texto avisa")
  func shortConversion() throws {
    let m = menu(try indefinite { $0.timedPresets = [3, 25] })
    #expect(m.newSession == [MenuAction("3 min (serán 5: el retraso al terminar)", .startTimed(3)),
                             MenuAction("25 min", .startTimed(25))])
  }

  @Test("Sin retraso, 'Terminar sesión' a secas")
  func noDelay() throws {
    #expect(menu(try indefinite { $0.stopDelayMinutes = 0 }).stop == MenuAction("Terminar sesión", .stop))
  }

  @Test("Con candado, terminar está desactivado y dice hasta cuándo")
  func locked() throws {
    let m = menu(try timed { $0.timedLock = true })
    #expect(m.stop == MenuAction("Terminar: con candado hasta las 08:25", .stop, enabled: false))
    #expect(menu(try indefinite { $0.timedLock = true }).stop?.enabled == true)
  }

  @Test("Terminación pendiente: 'Seguir trabajando' en vez de terminar")
  func stopPending() throws {
    let m = menu(try indefinite { $0.stopAt = at(15) }, now: at(10))
    #expect(m.stop == nil)
    #expect(m.cancelStop == MenuAction("Seguir trabajando", .cancelStop))
  }

  @Test("Pase en curso, sin pases o con pases desactivados")
  func passStates() throws {
    let active = menu(try indefinite { $0.passUntil = at(6); $0.passesUsed = 1 }, now: at(2))
    #expect(active.pass == MenuAction("Pase YouTube: en curso hasta las 08:06", .pass, enabled: false))
    let none = menu(try indefinite { $0.passesUsed = 3 })
    #expect(none.pass == MenuAction("Pase YouTube: no quedan (3 de 3)", .pass, enabled: false))
    #expect(menu(try indefinite { $0.passesMax = 0 }).pass == nil)
    let two = menu(try indefinite { $0.passGroups = ["youtube", "twitch"]; $0.passMinutes = 10 })
    #expect(two.pass?.title == "Pase YouTube y Twitch, 10 min (quedan 3)")
  }

  @Test("Con un comando en marcha, todo desactivado")
  func busy() throws {
    let m = menu(try indefinite(), busy: true)
    #expect(m.pass?.enabled == false && m.stop?.enabled == false)
    #expect(m.newSession.allSatisfy { !$0.enabled })
    #expect(menu(try indefinite { $0.stopAt = at(5) }, busy: true).cancelStop?.enabled == false)
  }
}

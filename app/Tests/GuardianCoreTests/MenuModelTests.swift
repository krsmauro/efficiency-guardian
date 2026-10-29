import Testing
@testable import GuardianCore

// El pase está en PassMenuTests; alargar y acortar, en SessionLengthMenuTests.
@Suite("Opciones del menú")
struct MenuModelTests {
  func menu(_ s: GuardianStatus, now: Int = T0, busy: Bool = false) -> MenuModel {
    MenuModel(status: s, now: now, busy: busy, timeZone: utc)
  }

  @Test("Sin sesión: nueva sesión con las duraciones y sin fin")
  func idle() throws {
    let m = menu(try status())
    #expect(m.newSession?.title == "Nueva sesión")
    #expect(m.newSession?.items.map(\.title) == ["25 min", "50 min", "90 min", "Sin fin"])
    #expect(m.newSession?.items.map(\.command) == [.startTimed(25), .startTimed(50), .startTimed(90), .start])
    #expect(m.stop == nil && m.cancelStop == nil && m.extend == nil && m.shorten == nil)
  }

  @Test("Las duraciones salen de la configuración del motor")
  func presetsFromEngine() throws {
    #expect(menu(try fixture("locked"), now: at(11)).newSession == nil)
    #expect(menu(try status { $0.timedPresets = [15, 45] }).newSession?.items.map(\.title) == ["15 min", "45 min", "Sin fin"])
  }

  @Test("Sesión sin fin: pasar a sesión por tiempo (sin 'Sin fin') y terminar con retraso")
  func indefiniteSession() throws {
    let m = menu(try indefinite(), now: at(10))
    #expect(m.newSession?.title == "Pasar a sesión por tiempo")
    #expect(m.newSession?.items.map(\.command) == [.startTimed(25), .startTimed(50), .startTimed(90)])
    #expect(m.stop == MenuAction("Terminar sesión (en 5 min)", .stop))
    #expect(m.cancelStop == nil && m.extend == nil && m.shorten == nil)
  }

  @Test("Sesión por tiempo: alargar y acortar en vez de nueva sesión")
  func timedSession() throws {
    let m = menu(try timed { $0.sessionEnds = at(50) })
    #expect(m.newSession == nil)
    #expect(m.extend?.title == "Alargar" && m.shorten?.title == "Acortar")
    #expect(m.stop == MenuAction("Terminar sesión (en 5 min)", .stop))
    #expect(menu(try timed(), now: at(21)).stop == MenuAction("Terminar sesión (ya termina a las 08:25)", .stop))
  }

  @Test("Pasar a sesión por tiempo con una duración menor que el retraso: el texto avisa")
  func shortConversion() throws {
    let m = menu(try indefinite { $0.timedPresets = [3, 25] })
    #expect(m.newSession?.items == [MenuAction("3 min (serán 5: el retraso al terminar)", .startTimed(3)),
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

  @Test("Terminación pendiente: solo 'Seguir trabajando'; ni terminar, ni alargar, ni acortar")
  func stopPending() throws {
    let m = menu(try indefinite { $0.stopAt = at(15) }, now: at(10))
    #expect(m.stop == nil)
    #expect(m.cancelStop == MenuAction("Seguir trabajando", .cancelStop))
    let t = menu(try timed { $0.sessionEnds = at(50); $0.stopAt = at(15) }, now: at(10))
    #expect(t.extend == nil && t.shorten == nil && t.cancelStop != nil)
  }

  @Test("Con un comando en marcha, todo desactivado")
  func busy() throws {
    let m = menu(try indefinite(), busy: true)
    #expect(m.pass == .action(MenuAction("Pase YouTube, 5 min (quedan 3)", .pass("youtube"), enabled: false)))
    #expect(m.stop?.enabled == false)
    #expect(m.newSession?.items.allSatisfy { !$0.enabled } == true)
    let t = menu(try timed { $0.sessionEnds = at(50); $0.passGroups = ["youtube", "x"] }, busy: true)
    for submenu in [t.extend, t.shorten] + [t.pass].map({ if case .submenu(let s) = $0 { s } else { nil } }) {
      #expect(submenu?.items.isEmpty == false && submenu?.items.allSatisfy { !$0.enabled } == true)
    }
    #expect(menu(try indefinite { $0.stopAt = at(5) }, busy: true).cancelStop?.enabled == false)
  }
}

import Testing
@testable import GuardianCore

// Fase 6, A (D16): las dos eligen la duración total; alargar no tiene tope ("Sin fin"),
// y acortar nunca termina antes que el retraso al terminar.
@Suite("Alargar y acortar en el menú")
struct SessionLengthMenuTests {
  func menu(_ s: GuardianStatus, now: Int = T0) -> MenuModel {
    MenuModel(status: s, now: now, timeZone: utc)
  }

  /// 50 min desde T0 (hasta las 08:50).
  func fifty(_ change: (inout GuardianStatus) -> Void = { _ in }) throws -> GuardianStatus {
    try timed { $0.sessionEnds = at(50); change(&$0) }
  }

  @Test("Alargar: las duraciones mayores, a su hora de fin, y 'Sin fin'")
  func extend() throws {
    #expect(menu(try timed(), now: at(10)).extend == Submenu("Alargar", [
      MenuAction("a 50 min (hasta las 08:50)", .extend(50)),
      MenuAction("a 90 min (hasta las 09:30)", .extend(90)),
      MenuAction("Sin fin", .extendEndless),
    ]))
    let longest = try timed { $0.sessionEnds = at(90) }
    #expect(menu(longest).extend == Submenu("Alargar", [MenuAction("Sin fin", .extendEndless)]))
  }

  @Test("Con candado se puede alargar, pero 'Sin fin' está desactivado y dice hasta cuándo")
  func extendLocked() throws {
    let items = menu(try fifty { $0.timedLock = true }).extend?.items
    #expect(items == [
      MenuAction("a 90 min (hasta las 09:30)", .extend(90)),
      MenuAction("Sin fin: con candado hasta las 08:50", .extendEndless, enabled: false),
    ])
  }

  @Test("Acortar: solo las duraciones menores, a su hora de fin")
  func shorten() throws {
    #expect(menu(try fifty(), now: at(10)).shorten == Submenu("Acortar", [
      MenuAction("a 25 min (termina a las 08:25)", .shorten(25)),
    ]))
    #expect(menu(try timed()).shorten == nil)  // 25 min: no hay ninguna menor
  }

  @Test("Acortar a una hora que llega antes que el retraso, o que ya pasó: lo dice")
  func shortenWithinDelay() throws {
    let option = { (now: Int) in try self.menu(self.fifty(), now: now).shorten?.items.first?.title }
    #expect(try option(at(19, seconds: 59)) == "a 25 min (termina a las 08:25)")
    #expect(try option(at(20)) == "a 25 min (termina en 5 min: el retraso al terminar)")
    #expect(try option(at(30)) == "a 25 min (termina en 5 min: el retraso al terminar)")
    let noDelay = try fifty { $0.stopDelayMinutes = 0 }
    #expect(menu(noDelay, now: at(25)).shorten?.items.first?.title == "a 25 min (termina ahora)")
  }

  @Test("Se mide desde que empezó la parte por tiempo (una sin fin convertida)")
  func fromTimedStart() throws {
    let s = try fixture("locked")  // convertida en el minuto 10 a 45 min; presets 15 y 45
    var unlocked = s
    unlocked.timedLock = false
    #expect(menu(unlocked, now: s.now).shorten?.items == [MenuAction("a 15 min (termina a las 08:25)", .shorten(15))])
    unlocked.timedPresets = [15, 45, 60]
    #expect(menu(unlocked, now: s.now).extend?.items.first == MenuAction("a 60 min (hasta las 09:10)", .extend(60)))
  }

  @Test("Con candado, acortar está desactivado y dice hasta cuándo")
  func locked() throws {
    #expect(menu(try fifty { $0.timedLock = true }).shorten
            == Submenu("Acortar: con candado hasta las 08:50", [], enabled: false))
  }

  @Test("El menú no cambia de un segundo a otro por alargar y acortar")
  func stable() throws {
    let s = try fifty()
    let first = MenuModel(status: s, now: at(10), timeZone: utc)
    for second in 1...59 {
      #expect(MenuModel(status: s, now: at(10, seconds: second), timeZone: utc) == first)
    }
  }
}

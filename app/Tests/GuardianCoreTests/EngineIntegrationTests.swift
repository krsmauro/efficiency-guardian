import Foundation
import Testing
@testable import GuardianCore

// El motor de verdad, sin root: ver EngineSandbox.

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
    #expect(MenuModel(status: timed, now: T0, timeZone: utc).pass
            == .action(MenuAction("Pase YouTube, 5 min (quedan 3)", .pass("youtube"))))

    engine.now = at(1)
    #expect(await engine.run(.pass("youtube")) == .success("Pase: youtube desbloqueado hasta las 08:06. Te quedan 2 de 3."))
    #expect(await engine.run(.pass("youtube")) == .failure("Ya hay un pase en curso: youtube, hasta las 08:06"))
    #expect(await engine.run(.stop) == .success(
      "El bloqueo sigue hasta las 08:06, por si cambias de opinión. "
        + "Para seguir trabajando: sudo /usr/local/sbin/guardian cancel-stop"))
    let pending = try #require(await engine.status().status)
    #expect(IconState.from(.ok(pending), now: at(1)).symbol == "ticket")
    #expect(MenuModel(status: pending, now: at(1), timeZone: utc).cancelStop?.command == .cancelStop)
    #expect(await engine.run(.cancelStop) == .success("Terminación cancelada: la sesión sigue."))
  }

  @Test("Rechazos del motor, explicados")
  func rejections() async throws {
    let engine = try EngineSandbox()
    #expect(await engine.run(.pass("youtube")) == .failure("No hay sesión: no hace falta un pase"))
    #expect(await engine.run(.startTimed(37))
            == .failure("37 min no es una duración permitida (TIMED_PRESETS: 25, 50, 90)"))
    guard case .failure(let usage) = await engine.run(["start", "025"]) else {
      Issue.record("start 025 debería fallar")
      return
    }
    #expect(usage.hasPrefix("Uso: guardian start [minutos]"))
  }

  @Test("Alargar, acortar y el pase de otro sitio: lo que ofrece el menú, el motor lo acepta")
  func phase6() async throws {
    let engine = try EngineSandbox()
    try engine.configure("PASS_GROUPS=youtube,facebook")
    #expect(await engine.run(.startTimed(25)) == .success("Sesión de 25 min iniciada: termina a las 08:25. 3 dominios bloqueados."))

    engine.now = at(1)
    var menu = MenuModel(status: try #require(await engine.status().status), now: engine.now, timeZone: utc)
    let extend = try #require(menu.extend?.items.first { $0.command == .extend(90) })
    #expect(extend.title == "a 90 min (hasta las 09:30)")
    #expect(await engine.run(extend.command) == .success("Sesión alargada a 90 min: termina a las 09:30."))

    engine.now = at(2)
    let longer = try #require(await engine.status().status)
    #expect(longer.sessionEnds == at(90) && longer.timedStarted == T0)
    menu = MenuModel(status: longer, now: engine.now, timeZone: utc)
    #expect(menu.shorten?.items.map(\.command) == [.shorten(25), .shorten(50)])
    let shorten = try #require(menu.shorten?.items.first)
    #expect(shorten.title == "a 25 min (termina a las 08:25)")
    #expect(await engine.run(shorten.command) == .success("Sesión acortada a 25 min: termina a las 08:25."))

    guard case .submenu(let passes) = MenuModel(status: try #require(await engine.status().status),
                                                now: engine.now, timeZone: utc).pass else {
      Issue.record("con dos sitios, el pase debería ser un submenú")
      return
    }
    let facebook = try #require(passes.items.last)
    #expect(facebook == MenuAction("Facebook", .pass("facebook")))
    #expect(await engine.run(facebook.command) == .success("Pase: facebook desbloqueado hasta las 08:07. Te quedan 2 de 3."))
    let during = try #require(await engine.status().status)
    #expect(during.passGroup == "facebook" && during.blockedDomains == 2)
  }

  @Test("Alargar ▸ Sin fin: el motor la pasa a sin fin y conserva los pases")
  func endless() async throws {
    let engine = try EngineSandbox()
    _ = await engine.run(.startTimed(25))
    _ = await engine.run(.pass("youtube"))
    let menu = MenuModel(status: try #require(await engine.status().status), now: engine.now, timeZone: utc)
    let endless = try #require(menu.extend?.items.last)
    #expect(endless == MenuAction("Sin fin", .extendEndless))
    #expect(await engine.run(endless.command) == .success(
      "La sesión ahora es sin fin: sigue hasta que la termines o apagues el Mac. Pases usados: 1 de 3."))
    let after = try #require(await engine.status().status)
    #expect(after.session == .indefinite && after.sessionEnds == 0 && after.passGroup == "youtube")
  }
}

import Testing
@testable import GuardianCore

@Suite("Resumen y configuración del menú")
struct MenuSummaryTests {
  func lines(_ result: StatusResult, now: Int = T0) -> [String] {
    MenuSummary.lines(result, now: now, timeZone: utc)
  }

  @Test("Sin leer, sin motor o con error")
  func problems() {
    #expect(lines(.loading) == ["Leyendo el estado…"])
    #expect(lines(.notInstalled)
            == ["El motor no está instalado", "Falta /usr/local/sbin/guardian: ejecuta sudo ./install.sh"])
    #expect(lines(.failed("Uno\nDos")) == ["No se pudo leer el estado:", "Uno", "Dos"])
  }

  @Test("Sin sesión")
  func idle() throws {
    #expect(lines(.ok(try status())) == ["Sin sesión", "Nada bloqueado"])
  }

  @Test("Sesión sin fin")
  func indefiniteSession() throws {
    #expect(lines(.ok(try indefinite()), now: at(10))
            == ["Sesión sin fin, desde las 08:00", "Pases usados: 0 de 3", "Bloqueando 82 dominios"])
  }

  @Test("Todo a la vez, como lo escribe el motor")
  func everything() throws {
    let s = try fixture("timed-pass-stop")
    #expect(lines(.ok(s), now: s.now) == [
      "Sesión por tiempo: termina a las 08:25 (quedan 21m)",
      "Terminación pendiente: se desbloquea a las 08:08",
      "Pase YouTube hasta las 08:06",
      "Pases usados: 1 de 3",
      "Bloqueando 1 dominio",
    ])
  }

  @Test("hosts va hasta 30 s por detrás de la sesión")
  func blockingLag() throws {
    #expect(lines(.ok(try status { $0.blocking = true })).last == "Bloqueo: se quita en menos de 30 s")
    #expect(lines(.ok(try indefinite { $0.blocking = false })).last == "Bloqueo: se aplica en menos de 30 s")
  }

  @Test("Un pase que cubre todos los grupos: el motor no escribe bloque mientras dura")
  func passCoversEverything() throws {
    let s = try indefinite { $0.blocking = false; $0.blockedDomains = 0; $0.passUntil = at(5) }
    #expect(lines(.ok(s), now: at(1)).last == "Nada bloqueado durante el pase")
  }

  @Test("Sin pases, no se cuentan")
  func noPasses() throws {
    #expect(!lines(.ok(try indefinite { $0.passesMax = 0 })).contains { $0.hasPrefix("Pases") })
  }

  @Test("Configuración")
  func settings() throws {
    #expect(MenuSummary.settings(try fixture("locked")) == [
      "Sesiones por tiempo: 15, 45 min",
      "Candado en sesiones por tiempo: sí",
      "Retraso al terminar: 5 min",
      "Sesión sin fin al encender el Mac: no",
      "Pases: 3 por sesión, de 5 min, uno a la vez (YouTube y Facebook)",
    ])
    #expect(MenuSummary.howToChange.first?.contains("/usr/local/etc/efficiency-guardian/config") == true)
  }
}
